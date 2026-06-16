import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { DatasetSource } from '../enum/source.enum';
import { label } from '../enum/label.enum';

@Entity('dataset_inventories')
export class dataset_inventories {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column()
  file_hash: string;

  @Column({ default: 'malware' })
  label: label;

  @Column({ type: 'enum', enum: DatasetSource, default: DatasetSource.SCAN })
  source: DatasetSource;

  @CreateDateColumn({ type: 'timestamp' })
  uploaded_at: Date;
}
