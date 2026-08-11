import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from "typeorm";
import { application_type, os_type } from "../../users/enum/devices.enum";
import { User } from "../../users/entity/user.entity";

@Entity()
export class Device {
    @PrimaryGeneratedColumn()
    public id!: number;

    @Column({ type: "integer", nullable: false })
    public user_id!: number;

    @Column({ type: "varchar", nullable: false })
    public hardware_id!: string;

    @Column({ type: "varchar", nullable: false })
    public hostname!: string;

    @Column({ type: "enum", enum: os_type, nullable: false })
    public os_type!: os_type;

    @Column({ type: "enum", enum: application_type, nullable: false })
    public app_type!: application_type;

    @Column({ type: 'timestamp', nullable: true })
    public last_active!: Date | null;

    @Column({ type: 'timestamp', nullable: true })
    public last_login!: Date | null;

    @Column()
    public is_active!: boolean;

    @ManyToOne(() => User, user => user.id)
    @JoinColumn({ name: "user_id" })
    public user!: User;
}
