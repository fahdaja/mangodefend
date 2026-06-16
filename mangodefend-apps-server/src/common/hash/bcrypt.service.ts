import { Injectable } from "@nestjs/common";
import *as bcrypt from "bcrypt";

@Injectable()
export class BcryptService {
    public async hashPassword(password: string): Promise<string> {
        const saltRounds = 10;
        return await bcrypt.hash(password, saltRounds);
    }

    public async comparePassword(password:string, hashed:string): Promise<boolean> {
        return await bcrypt.compare(password, hashed);
    }
}
