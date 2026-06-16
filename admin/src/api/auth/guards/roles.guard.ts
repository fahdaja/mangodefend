import { CanActivate, ExecutionContext, UnauthorizedException, Injectable } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { Role } from "src/api/users/enum/roles.enum";
import { Roles, ROLES_KEY } from "src/common/decorator/roles.decorator";

@Injectable()
export class RoleGuard implements CanActivate{
    constructor (private readonly reflector: Reflector){}

    canActivate(context: ExecutionContext): boolean  {
        const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
            context.getHandler(),
            context.getClass()
        ])    
        if (!requiredRoles){
            return true;
        }
        const { user } = context.switchToHttp().getRequest();
        
        // Cek user.role (karena di auth service payloadnya memakai 'role' bukan 'roles')
        const hasRole = requiredRoles.some((role) => user.role === role)
        if(!hasRole){
            throw new UnauthorizedException('Anda tidak memiliki izin akses ke halaman ini')
        }
        return true
    }
}