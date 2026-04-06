import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { AuthService } from '../../core/auth.service';
import { ApiService } from '../../core/api.service';

@Component({
  selector: 'app-super-user',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page">
      <!-- Header -->
      <div class="header">
        <span class="app-name">UDS ⚙</span>
        <div class="tabs">
          <button class="tab-btn" [class.active]="activeTab==='users'" (click)="activeTab='users'">Users</button>
          <button class="tab-btn" [class.active]="activeTab==='assignments'" (click)="activeTab='assignments';loadApps()">App Assignments</button>
          <button class="tab-btn" [class.active]="activeTab==='help'" (click)="activeTab='help'">Help</button>
        </div>
        <span class="user-name" (click)="logout()" style="cursor:pointer" title="Logout">
          {{ user?.firstName }} {{ user?.lastName }} ▾
        </span>
      </div>

      <!-- Users Tab -->
      <div class="content" *ngIf="activeTab==='users'">
        <div class="toolbar">
          <input class="filter-input" [(ngModel)]="userFilter" placeholder="Filter users...">
          <button class="btn btn-primary" (click)="openForm(null)">+ Add User</button>
        </div>

        <!-- User Form -->
        <div class="form-panel" *ngIf="showForm">
          <h3>{{ editUser ? 'Edit User' : 'Create User' }}</h3>
          <div class="form-grid">
            <div class="form-group">
              <label>First Name</label>
              <input [(ngModel)]="form.firstName">
            </div>
            <div class="form-group">
              <label>Last Name</label>
              <input [(ngModel)]="form.lastName">
            </div>
            <div class="form-group">
              <label>Username</label>
              <input [(ngModel)]="form.username" [disabled]="!!editUser">
            </div>
            <div class="form-group" *ngIf="!editUser">
              <label>Password</label>
              <input type="password" [(ngModel)]="form.password">
            </div>
            <div class="form-group">
              <label>Email</label>
              <input [(ngModel)]="form.email">
            </div>
            <div class="form-group">
              <label>Role</label>
              <select [(ngModel)]="form.role">
                <option value="APP_MANAGER">Application Manager</option>
                <option value="PROJECT_OFFICER">Project Officer</option>
                <option value="APP_USER">Application User</option>
              </select>
            </div>
            <div class="form-group" *ngIf="editUser">
              <label>Status</label>
              <select [(ngModel)]="form.status">
                <option value="ACTIVE">Active</option>
                <option value="INACTIVE">Inactive</option>
              </select>
            </div>
          </div>
          <div class="form-actions">
            <button class="btn btn-primary" (click)="saveUser()">Save</button>
            <button class="btn btn-secondary" (click)="showForm=false">Cancel</button>
          </div>
          <div class="error-msg" *ngIf="formError">{{ formError }}</div>
        </div>

        <table class="data-table">
          <thead>
            <tr>
              <th>User ID</th><th>First Name</th><th>Last Name</th><th>Username</th><th>Role</th><th>Status</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let u of filteredUsers()">
              <td>{{ u.userId }}</td>
              <td>{{ u.firstName }}</td>
              <td>{{ u.lastName }}</td>
              <td>{{ u.username }}</td>
              <td>{{ u.role }}</td>
              <td><span [class]="'badge badge-' + u.status.toLowerCase()">{{ u.status }}</span></td>
              <td>
                <button class="icon-btn" (click)="openForm(u)" title="Edit">✏️</button>
                <button class="icon-btn" (click)="deleteUser(u)" title="Delete">🗑️</button>
              </td>
            </tr>
            <tr *ngIf="filteredUsers().length===0">
              <td colspan="7" style="text-align:center;color:#888">No users found.</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- App Assignments Tab -->
      <div class="content" *ngIf="activeTab==='assignments'">
        <div class="split-panel">
          <div class="left-list">
            <h3>Applications</h3>
            <div class="app-item" *ngFor="let app of apps"
                 [class.selected]="selectedApp?.appId===app.appId"
                 (click)="selectApp(app)">
              <strong>{{ app.appName }}</strong><br>
              <small>{{ app.appId }}</small>
            </div>
            <div *ngIf="apps.length===0" style="color:#888;font-size:0.85rem">No applications.</div>
          </div>
          <div class="right-detail" *ngIf="selectedApp">
            <h3>Managers for {{ selectedApp.appName }}</h3>
            <div class="assign-input">
              <input [(ngModel)]="assignUserId" placeholder="User ID to assign">
              <button class="btn btn-primary" (click)="assignManager()">Assign</button>
            </div>
            <table class="data-table" style="margin-top:12px">
              <thead><tr><th>User ID</th><th>Assigned At</th><th>Remove</th></tr></thead>
              <tbody>
                <tr *ngFor="let m of managers">
                  <td>{{ m.managerUserId }}</td>
                  <td>{{ m.assignedAt | date:'short' }}</td>
                  <td><button class="icon-btn" (click)="removeManager(m.managerUserId)">✖</button></td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="right-detail" *ngIf="!selectedApp" style="display:flex;align-items:center;justify-content:center;color:#888">
            Select an application to manage assignments
          </div>
        </div>
      </div>

      <!-- Help Tab -->
      <div class="content" *ngIf="activeTab==='help'">
        <h3>Help</h3>
        <iframe *ngIf="helpSrc" [src]="helpSrc" style="width:100%;height:600px;border:1px solid #ddd;border-radius:4px"></iframe>
      </div>
    </div>
  `,
  styles: [`
    .page { min-height:100vh; background:#f5f5f5; }
    .split-panel { display:flex; gap:16px; height:calc(100vh - 120px); }
    .left-list { width:260px; background:white; border-radius:4px; padding:12px; overflow-y:auto; }
    .right-detail { flex:1; background:white; border-radius:4px; padding:16px; overflow-y:auto; }
    .app-item { padding:8px; border-bottom:1px solid #eee; cursor:pointer; border-radius:4px; }
    .app-item:hover, .app-item.selected { background:#e8eaf6; }
    .assign-input { display:flex; gap:8px; }
    .assign-input input { flex:1; padding:6px; border:1px solid #ccc; border-radius:4px; }
    .form-panel { background:white; padding:16px; border-radius:4px; margin-bottom:16px; border:1px solid #e0e0e0; }
    .form-grid { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
    .form-actions { display:flex; gap:8px; margin-top:12px; }
    .badge { padding:2px 8px; border-radius:10px; font-size:0.75rem; }
    .badge-active { background:#e8f5e9; color:#2e7d32; }
    .badge-inactive { background:#ffebee; color:#c62828; }
    .toolbar { display:flex; gap:8px; margin-bottom:12px; align-items:center; }
    .error-msg { color:#c62828; font-size:0.85rem; margin-top:8px; }
  `]
})
export class SuperUserComponent implements OnInit {
  activeTab = 'users';
  user: any = null;
  users: any[] = [];
  apps: any[] = [];
  managers: any[] = [];
  selectedApp: any = null;
  userFilter = '';
  showForm = false;
  editUser: any = null;
  form: any = {};
  formError = '';
  assignUserId = '';
  helpSrc: SafeResourceUrl | null = null;

  constructor(private auth: AuthService, private api: ApiService, private sanitizer: DomSanitizer) {}

  ngOnInit(): void {
    this.user = this.auth.getCurrentUser();
    this.loadUsers();
    this.api.getHelp('SUPER_USER').subscribe({
      next: blob => { this.helpSrc = this.sanitizer.bypassSecurityTrustResourceUrl(URL.createObjectURL(blob)); },
      error: () => {}
    });
  }

  loadUsers(): void {
    this.api.getUsers().subscribe({ next: u => this.users = u, error: () => {} });
  }

  loadApps(): void {
    this.api.getApplications().subscribe({ next: a => this.apps = a, error: () => {} });
  }

  filteredUsers(): any[] {
    if (!this.userFilter) return this.users;
    const f = this.userFilter.toLowerCase();
    return this.users.filter(u =>
      u.firstName?.toLowerCase().includes(f) ||
      u.lastName?.toLowerCase().includes(f) ||
      u.username?.toLowerCase().includes(f) ||
      u.role?.toLowerCase().includes(f)
    );
  }

  openForm(u: any | null): void {
    this.editUser = u;
    this.form = u ? { ...u } : { role: 'APP_MANAGER', status: 'ACTIVE' };
    this.showForm = true;
    this.formError = '';
  }

  saveUser(): void {
    this.formError = '';
    if (this.editUser) {
      this.api.updateUser(this.editUser.userId, {
        firstName: this.form.firstName,
        lastName: this.form.lastName,
        email: this.form.email,
        status: this.form.status
      }).subscribe({ next: () => { this.showForm = false; this.loadUsers(); }, error: () => this.formError = 'Save failed.' });
    } else {
      this.api.createUser(this.form).subscribe({ next: () => { this.showForm = false; this.loadUsers(); }, error: () => this.formError = 'Create failed.' });
    }
  }

  deleteUser(u: any): void {
    if (!confirm(`Delete user ${u.firstName} ${u.lastName}?`)) return;
    this.api.deleteUser(u.userId).subscribe({ next: () => this.loadUsers(), error: () => {} });
  }

  selectApp(app: any): void {
    this.selectedApp = app;
    this.api.getManagers(app.appId).subscribe({ next: m => this.managers = m, error: () => {} });
  }

  assignManager(): void {
    if (!this.assignUserId || !this.selectedApp) return;
    this.api.assignManager(this.selectedApp.appId, this.assignUserId).subscribe({
      next: () => { this.assignUserId = ''; this.selectApp(this.selectedApp); },
      error: () => {}
    });
  }

  removeManager(userId: string): void {
    this.api.removeManager(this.selectedApp.appId, userId).subscribe({
      next: () => this.selectApp(this.selectedApp), error: () => {}
    });
  }

  logout(): void { this.auth.logout(); }
}
