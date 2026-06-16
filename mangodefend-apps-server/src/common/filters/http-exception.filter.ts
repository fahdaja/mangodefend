import { ExceptionFilter, Catch, ArgumentsHost, HttpException } from '@nestjs/common';
import { Response } from 'express';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    // Jika exceptionResponse adalah string, ubah ke object
    const errorResponse = typeof exceptionResponse === 'string'
      ? { message: exceptionResponse }
      : exceptionResponse;

    // Jika message adalah array, join menjadi string
   if (errorResponse && typeof errorResponse === 'object' && 'message' in errorResponse && Array.isArray(errorResponse.message)) {
  errorResponse.message = errorResponse.message.join(', ');
}
    response.status(status).json({
      ...errorResponse,
      statusCode: status,
    });
  }
}