import { Column, Entity, JoinColumn, ManyToOne, OneToMany, PrimaryGeneratedColumn } from "typeorm";
import { Role } from "../enum/roles.enum";
import { application_type, os_type } from "../enum/devices.enum";
import { Plans, Subscriptions } from "src/api/subscriptions/entity/subscription.entity";
import { AuthProvider } from "../enum/auth-provider.enum";


@Entity()
export class User {
    @PrimaryGeneratedColumn()
    public id!: number;

    @Column({ type: "varchar", length: 255, unique: true })
    public email!: string;

    @Column({ type: "varchar", nullable: true })
    public password!: string | null;

    @Column({ type: "enum", enum: Role, default: Role.CLIENT })
    public role!: Role;

    @Column({ type: "enum", enum: AuthProvider, default: AuthProvider.LOCAL })
    public auth_provider!: AuthProvider;

    @Column({ type: "varchar", nullable: true, unique: true })
    public firebase_uid!: string | null;

    @Column({ type: "varchar", nullable: true })
    public display_name!: string | null;

    @Column({ type: "varchar", nullable: true })
    public photo_url!: string | null;

    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" })
    public createdAt!: Date;

    @OneToMany(() => Device, userDevice => userDevice.user)
    devices!: Device[];
    @OneToMany(() => Plans, plans => plans.user)
    plans!: Plans[]
    @OneToMany(() => Subscriptions, sub => sub.user)
    subscriptions!: Subscriptions[]
}

@Entity()
export class Device {
    @PrimaryGeneratedColumn()
    public id!: number;

    @Column({ type: "integer", nullable: false})
    public user_id!: number;

    @Column({ type: "varchar",  nullable: false })
    public hardware_id!: string;

    @Column({ type: "varchar",  nullable: false })
    public hostname!: string;

    @Column( {type: "enum", enum: os_type, nullable: false} )
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

