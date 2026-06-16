import { Module } from "@nestjs/common";
import { UserController } from "./controllers/user.controller";
import { UserService } from "./services/user.service";
import { TypeOrmModule } from "@nestjs/typeorm";
import { User, Device } from "./entity/user.entity";
import { HashModule } from "../../common/hash/hash.module";
import { AuthModule } from "../auth/auth.module";
import { Plans, Subscriptions } from "../subscriptions/entity/subscription.entity";


@Module({
    imports: [TypeOrmModule.forFeature([User, Device, Plans, Subscriptions]), HashModule, AuthModule],
    controllers: [UserController],
    providers: [UserService],
    exports: [UserService],
})

export class UserModule {}