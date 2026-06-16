import {
  Column,
  Entity,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ScanStatus, ScanType } from '../enum/scan.enum';

@Entity('summary_scans')
export class summary_scans {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  user_id: number;

  @Column({ type: 'enum', enum: ScanType })
  scan_type: ScanType;

  @Column({ type: 'enum', enum: ScanStatus })
  status: ScanStatus;

  @Column()
  total_files_scanned: number;

  @Column({ default: 0 })
  total_malware_detected: number;

  @CreateDateColumn({ type: 'timestamp' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamp' })
  updated_at: Date;

  // Relasi: satu summary punya banyak detail
  @OneToMany(() => scan_details, (detail) => detail.summary)
  details: scan_details[];
}

@Entity('scan_details')
export class scan_details {
  @PrimaryGeneratedColumn()
  id: number;

  // Foreign Key kolom
  @Column()
  summary_id: number;

  // Relasi: banyak detail milik satu summary
  @ManyToOne(() => summary_scans, (summary) => summary.details)
  @JoinColumn({ name: 'summary_id' })
  summary: summary_scans;

  @Column()
  file_name: string;

  @Column({ nullable: true })
  file_hash: string;

  @Column({ default: false })
  is_malware: boolean;

  @Column({ default: false })
  matched_in_library: boolean;

  @CreateDateColumn({ type: 'timestamp' })
  detected_at: Date;
}
