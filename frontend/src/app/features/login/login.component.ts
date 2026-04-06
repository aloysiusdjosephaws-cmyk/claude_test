import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="login-page">
      <div class="login-card">
        <div class="login-header">
          <h1>UDS — Upload Download Service</h1>
          <p>Sign in to continue</p>
        </div>
        <div class="login-body">
          <div class="form-group">
            <label>Username</label>
            <input type="text" [(ngModel)]="username" placeholder="Enter username" (keyup.enter)="login()">
          </div>
          <div class="form-group">
            <label>Password</label>
            <input type="password" [(ngModel)]="password" placeholder="Enter password" (keyup.enter)="login()">
          </div>
          <div class="error-msg" *ngIf="error">{{ error }}</div>
          <button class="btn btn-primary login-btn" (click)="login()" [disabled]="loading">
            {{ loading ? 'Signing in...' : 'Sign In' }}
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .login-page { display:flex; align-items:center; justify-content:center; min-height:100vh; background:#f0f2f5; }
    .login-card { background:white; border-radius:8px; box-shadow:0 2px 16px rgba(0,0,0,0.12); width:360px; overflow:hidden; }
    .login-header { background:#1a237e; color:white; padding:24px; text-align:center; }
    .login-header h1 { font-size:1.3rem; margin-bottom:4px; }
    .login-header p { font-size:0.85rem; opacity:0.8; }
    .login-body { padding:24px; }
    .error-msg { color:#c62828; font-size:0.85rem; margin-bottom:12px; }
    .login-btn { width:100%; padding:10px; margin-top:8px; font-size:1rem; }
  `]
})
export class LoginComponent {
  username = '';
  password = '';
  error = '';
  loading = false;

  constructor(private auth: AuthService, private router: Router) {}

  login(): void {
    if (!this.username || !this.password) {
      this.error = 'Please enter username and password.';
      return;
    }
    this.loading = true;
    this.error = '';
    this.auth.login(this.username, this.password).subscribe({
      next: () => {
        const role = this.auth.getUserRole();
        const routes: Record<string, string> = {
          SUPER_USER: '/super-user',
          PROJECT_OFFICER: '/project-officer',
          APP_MANAGER: '/app-manager',
          APP_USER: '/app-user'
        };
        this.router.navigate([routes[role!] ?? '/login']);
      },
      error: () => {
        this.error = 'Invalid username or password.';
        this.loading = false;
      }
    });
  }
}
