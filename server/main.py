from bisect import bisect_left
from functools import lru_cache
from pathlib import Path

import joblib
import pandas as pd
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel, Field
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from sklearn.svm import SVC

app = FastAPI()

BMI_CUT_POINTS = (18.5, 23.0, 25.0, 30.0, 35.0)
GLUCOSE_CUT_POINTS = (70, 100, 126)
ARTIFACT_DIR = Path(__file__).resolve().parent / "artifacts"
MODEL_INPUT_COLUMNS = (
    "임신횟수",
    "저체중",
    "정상",
    "비만 전단계",
    "1단계 비만",
    "2단계 비만",
    "3단계 비만",
    "혈당_저혈당",
    "혈당_정상",
    "혈당_당뇨병 전단계",
    "혈당_당뇨병",
)


class DiagnosisInput(BaseModel):
    age: int = Field(ge=0, strict=True)
    weight_kg: float = Field(gt=0, allow_inf_nan=False, alias="weightKg")
    height_cm: float = Field(gt=0, allow_inf_nan=False, alias="heightCm")
    blood_glucose_mg_dl: float = Field(
        gt=0, allow_inf_nan=False, alias="bloodGlucoseMgDl"
    )
    pregnancy_count: int = Field(ge=0, strict=True, alias="pregnancyCount")


class DiagnosisResponse(BaseModel):
    result: str


@lru_cache(maxsize=2)
def load_artifacts(group: str) -> tuple[SVC, MinMaxScaler | StandardScaler]:
    model = joblib.load(ARTIFACT_DIR / f"{group}_svc.h5")
    scaler = joblib.load(ARTIFACT_DIR / f"{group}_scaler.h5")
    if not isinstance(model, SVC):
        raise TypeError("Expected a scikit-learn SVC model")
    if not isinstance(scaler, (MinMaxScaler, StandardScaler)):
        raise TypeError("Expected a scikit-learn MinMaxScaler or StandardScaler")
    if tuple(scaler.feature_names_in_) != MODEL_INPUT_COLUMNS:
        raise ValueError("Scaler feature names or order do not match the input")
    if model.n_features_in_ != scaler.n_features_in_:
        raise ValueError("Scaler and SVC feature counts do not match")
    return model, scaler


def build_model_features(data: DiagnosisInput) -> list[int]:
    height_m = data.height_cm / 100
    bmi = data.weight_kg / height_m / height_m
    bmi_category = bisect_left(BMI_CUT_POINTS, bmi)
    glucose_category = bisect_left(GLUCOSE_CUT_POINTS, data.blood_glucose_mg_dl)

    # Training column order: pregnancy count, six BMI flags, four glucose flags.
    bmi_flags = [int(i == bmi_category) for i in range(len(BMI_CUT_POINTS) + 1)]
    glucose_flags = [
        int(i == glucose_category) for i in range(len(GLUCOSE_CUT_POINTS) + 1)
    ]
    return [data.pregnancy_count, *bmi_flags, *glucose_flags]


def predict_label(data: DiagnosisInput, group: str) -> str:
    features = build_model_features(data)
    model, scaler = load_artifacts(group)
    input_row = pd.DataFrame([features], columns=MODEL_INPUT_COLUMNS)
    prediction = model.predict(scaler.transform(input_row))[0]
    return {0: "정상", 1: "당뇨"}[prediction]


def check_age_34_or_under(data: DiagnosisInput) -> str:
    label = predict_label(data, "young_aged")
    return f"{data.age}세 · 청년\n모델 예측: {label}"


def check_age_over_34(data: DiagnosisInput) -> str:
    label = predict_label(data, "middle_old_aged")
    return f"{data.age}세 · 중장년\n모델 예측: {label}"


@app.post("/diagnosis", response_model=DiagnosisResponse)
def diagnose(data: DiagnosisInput) -> DiagnosisResponse:
    if data.age <= 34:
        result = check_age_34_or_under(data)
    else:
        result = check_age_over_34(data)
    return DiagnosisResponse(result=result)


def main() -> None:
    uvicorn.run(app, host="127.0.0.1", port=8000)


if __name__ == "__main__":
    main()
