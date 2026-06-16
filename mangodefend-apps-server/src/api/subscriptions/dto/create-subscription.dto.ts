import { IsNotEmpty, IsNumber, IsOptional } from "class-validator";

export class CreateSubscriptionDto {
    @IsOptional()
    @IsNumber()
    user_id?: number;

    @IsNotEmpty()
    @IsNumber()
    plan_id!: number;
}
