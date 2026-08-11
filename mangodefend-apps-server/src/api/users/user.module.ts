import { Module } from "@nestjs/common";
import { UserController } from "./controller/user.controller";
import { UserService } from "./service/user.service";
import { TypeOrmModule } from "@nestjs/typeorm";
import { User, Device } from "./entity/user.entity";
import { Plans, Subscriptions } from "../subscriptions/entity/subscription.entity";

import { HashModule } from "../../common/hash/hash.module";
import { AuthModule } from "../auth/auth.module";

@Module({
    imports: [TypeOrmModule.forFeature([User, Device, Plans, Subscriptions]), HashModule, AuthModule],
    controllers: [UserController],
    providers: [UserService],
    exports: [UserService],
})

export class UserModule {}