import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import Database from 'better-sqlite3';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  readonly db: Database.Database;

  constructor() {
    const url = process.env.DATABASE_URL ?? './dev.db';
    const dbPath = url.startsWith('file:') ? url.slice(5) : url;
    this.db = new Database(dbPath);
    this.db.pragma('journal_mode = WAL');
  }

  onModuleInit() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS task (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        title     TEXT    NOT NULL,
        content   TEXT,
        done      INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
      )
    `);
    this.logger.log('Base de données initialisée');
  }

  onModuleDestroy() {
    this.db.close();
  }
}
