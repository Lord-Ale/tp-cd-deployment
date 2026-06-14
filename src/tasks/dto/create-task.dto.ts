import { IsString, IsOptional, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateTaskDto {
  @ApiProperty({ example: 'Mettre à jour la documentation' })
  @IsString()
  title: string;

  @ApiPropertyOptional({ example: 'Ajouter les exemples curl dans le README' })
  @IsOptional()
  @IsString()
  content?: string;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  done?: boolean;
}
