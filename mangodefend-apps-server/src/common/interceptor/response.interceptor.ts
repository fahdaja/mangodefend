import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      map(data => {

        if (Array.isArray(data)) {
          return data; 
        }
        // Jika data sudah memiliki message, itu response sukses
        if (data && typeof data === 'object' && 'message' in data) {
          return {
            ...data,
          };
        }
        // Untuk response sukses lainnya, tambahkan success: true
        return typeof data === 'object' ? { ...data } : data;
      }),
    );
  }
}