import { ConsoleLogger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

export class FileLogger extends ConsoleLogger {
  private logFilePath = path.join(process.cwd(), 'nestjs_server.log');

  constructor() {
    super();
    // Truncate/reset log file at startup so it starts fresh
    try {
      fs.writeFileSync(this.logFilePath, `INFO:     [NestJS Apps Server] Logging started...\n`);
    } catch (e) {
      console.error('Failed to initialize NestJS log file:', e);
    }
  }

  log(message: any, context?: string) {
    super.log(message, context);
    this.writeToFile('INFO', message, context);
  }

  error(message: any, stack?: string, context?: string) {
    super.error(message, stack, context);
    this.writeToFile('ERROR', `${message}${stack ? `\nStack: ${stack}` : ''}`, context);
  }

  warn(message: any, context?: string) {
    super.warn(message, context);
    this.writeToFile('WARNING', message, context);
  }

  debug(message: any, context?: string) {
    super.debug(message, context);
    this.writeToFile('DEBUG', message, context);
  }

  verbose(message: any, context?: string) {
    super.verbose(message, context);
    this.writeToFile('VERBOSE', message, context);
  }

  private writeToFile(level: string, message: any, context?: string) {
    try {
      // Format log line to be readable like console output
      const ctxStr = context ? `[${context}] ` : '';
      const cleanMessage = typeof message === 'object' ? JSON.stringify(message, null, 2) : message;
      const logLine = `${level}:     ${ctxStr}${cleanMessage}\n`;
      fs.appendFileSync(this.logFilePath, logLine);
    } catch (e) {
      // Don't throw errors to prevent app crashes due to log file locking
    }
  }
}
