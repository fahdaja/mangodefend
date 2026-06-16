import { SetMetadata } from "@nestjs/common";
import { Role } from "src/api/users/enum/roles.enum";

export const ROLES_KEY = 'roles'
export const Roles = (...roles: Role[]) => SetMetadata('roles', roles)