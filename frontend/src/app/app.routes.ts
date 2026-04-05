import { Routes } from '@angular/router';
import { LoginComponent } from './features/login/login.component';
import { SuperUserComponent } from './features/super-user/super-user.component';
import { ProjectOfficerComponent } from './features/project-officer/project-officer.component';
import { AppManagerComponent } from './features/app-manager/app-manager.component';
import { AppUserComponent } from './features/app-user/app-user.component';
import { RoleGuard } from './core/role.guard';

export const routes: Routes = [
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'super-user', component: SuperUserComponent, canActivate: [RoleGuard], data: { role: 'SUPER_USER' } },
  { path: 'project-officer', component: ProjectOfficerComponent, canActivate: [RoleGuard], data: { role: 'PROJECT_OFFICER' } },
  { path: 'app-manager', component: AppManagerComponent, canActivate: [RoleGuard], data: { role: 'APP_MANAGER' } },
  { path: 'app-user', component: AppUserComponent, canActivate: [RoleGuard], data: { role: 'APP_USER' } },
  { path: '**', redirectTo: '/login' }
];
