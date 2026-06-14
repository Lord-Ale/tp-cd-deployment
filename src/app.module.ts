import { Module } from '@nestjs/common';
import { TasksModule } from './tasks/tasks.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [TasksModule, HealthModule],
})
export class AppModule {}
