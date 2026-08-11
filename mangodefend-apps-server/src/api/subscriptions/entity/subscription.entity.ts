import { Column, Entity, JoinColumn, ManyToOne, OneToMany, PrimaryGeneratedColumn } from "typeorm";
import { PlanType } from "../enum/plan.enum";
import { User } from "../../users/entity/user.entity";
import { MlModel } from "../../ml/entity/ml.entity";

export enum SubscriptionStatus {
    ACTIVE = 'ACTIVE',
    EXPIRED = 'EXPIRED',
    INACTIVE = 'INACTIVE',
    CANCELED = 'CANCELED',
}

@Entity()
export class Plans {
    @PrimaryGeneratedColumn()
    id!: number

    @Column({ type: "integer", nullable: true })
    user_id!: number | null

    @Column({ type: "enum", enum: PlanType})
    plan_name!: PlanType

    @Column({ type: "text"})
    description!: string

    @Column({ type: "decimal", precision: 10, scale: 2 })
    price!: number

    @Column({ type: "integer"})
    durationDays!: number

    @Column({ type: "integer", default: 2 })
    device_limit!: number

    @Column({ type: "integer", default: 5 })
    upload_file_limit!: number

    @Column({ type: "integer", default: 1 })
    full_scan_limit!: number

    @Column({ type: "integer", nullable: true })
    model_id!: number | null

    @ManyToOne(() => User, user => user.plans, { nullable: true })
    @JoinColumn({ name: "user_id" })
    user!: User

    @ManyToOne(() => MlModel, model => model.plans, { nullable: true })
    @JoinColumn({ name: "model_id" })
    model!: MlModel;

    @OneToMany(() => Subscriptions, sub => sub.plan)
    subscriptions!: Subscriptions[]
}

@Entity()
export class Subscriptions{
    @PrimaryGeneratedColumn()
    id!: number

    @Column({ type: "integer" })
    user_id!: number

    @Column({ type: "integer"})
    plan_id!: number

    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" })
    start_date!: Date
    
    @Column({ type: "timestamp" })
    end_date!: Date

    @Column({ type: "boolean", default: true })
    is_active!: boolean

    @Column({ type: "enum", enum: SubscriptionStatus, default: SubscriptionStatus.ACTIVE })
    status!: SubscriptionStatus

    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP", onUpdate: "CURRENT_TIMESTAMP" })
    update_at!: Date

    @ManyToOne(() => User, user => user.subscriptions)
    @JoinColumn({ name: "user_id"})
    user!: User

    @ManyToOne(() => Plans, plan => plan.subscriptions)
    @JoinColumn({ name: "plan_id"})
    plan!: Plans
}