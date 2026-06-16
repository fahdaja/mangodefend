import { IsEnum, IsNotEmpty, IsNumber, IsOptional } from "class-validator";
import { Method } from "../enum/method.enum";

export class CreateTransactionDto {
    @IsOptional()
    @IsNumber()
    user_id?: number;

    @IsNotEmpty()
    @IsNumber()
    plan_id!: number;

    @IsNotEmpty()
    @IsEnum(Method)
    method!: Method;
}
