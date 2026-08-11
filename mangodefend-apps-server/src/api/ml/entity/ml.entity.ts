import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, OneToMany } from "typeorm";
import { Plans } from "../../subscriptions/entity/subscription.entity";

@Entity('ml_models')
export class MlModel {
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ unique: true })
    version!: string;

    @Column()
    file_path!: string;

    @Column()
    checksum!: string;

    @Column({ default: true })
    is_active!: boolean;

    @CreateDateColumn()
    created_at!: Date;

    @OneToMany(() => Plans, plan => plan.model)
    plans!: Plans[];
}
