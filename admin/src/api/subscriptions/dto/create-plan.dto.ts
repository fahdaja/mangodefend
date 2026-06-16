import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString } from "class-validator";
import { PlanType } from "../enum/plan.enum";

export class CreatePlanDto {
    @IsNumber()
    @IsOptional()
    id?: number;

    @IsOptional()
    @IsNumber()
    user_id?: number;

    @IsNotEmpty()
    @IsEnum(PlanType)
    plan_name!: PlanType;

    @IsNotEmpty()
    @IsString()
    description!: string;

    @IsNotEmpty()
    @IsNumber()
    price!: number;

    @IsNotEmpty()
    @IsNumber()
    durationDays!: number;

    @IsNotEmpty()
    @IsNumber()
    model_id!: number;

    @IsOptional()
    @IsNumber()
    upload_file_limit?: number;

    @IsOptional()
    @IsNumber()
    full_scan_limit?: number;
}
