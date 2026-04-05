import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { AuthService } from '../../core/auth.service';
import { ApiService } from '../../core/api.service';

@Component({
  selector: 'app-project-officer',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page">
      <div class="header">
        <span class="app-name">Application Manager ⚙</span>
        <div class="tabs">
          <button class="tab-btn" [class.active]="tab==='apps'" (click)="tab='apps'">Applications</button>
          <button class="tab-btn" [class.active]="tab==='users'" (click)="tab='users';loadUsers()">Users</button>
          <button class="tab-btn" [class.active]="tab==='assign'" (click)="tab='assign';loadApps();loadAllUsers()">Assignments</button>
          <button class="tab-btn" [class.active]="tab==='help'" (click)="tab='help'">Help</button>
        </div>
        <span class="user-name" (click)="logout()" style="cursor:pointer" title="Logout">
          {{ user?.firstName }} {{ user?.lastName }} ▾
        </span>
      </div>

      <!-- Applications Tab -->
      <div class="content" *ngIf="tab==='apps'">
        <div class="toolbar">
          <input class="filter-input" [(ngModel)]="appFilter" placeholder="Filter applications...">
          <button class="btn btn-primary" (click)="openAppForm(null)">+ New Application</button>
        </div>
        <div class="form-panel" *ngIf="showAppForm">
          <h3>{{ editApp ? 'Edit Application' : 'New Application' }}</h3>
          <div class="form-group"><label>App Name</label><input [(ngModel)]="appForm.appName"></div>
          <div class="form-group"><label>Description</label><textarea [(ngModel)]="appForm.description" rows="3"></textarea></div>
          <div class="form-actions">
            <button class="btn btn-primary" (click)="saveApp()">Save</button>
            <button class="btn btn-secondary" (click)="showAppForm=false">Cancel</button>
          </div>
        </div>
        <table class="data-table">
          <thead><tr><th>App ID</th><th>Name</th><th>Description</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            <tr *ngFor="let a of filteredApps()">
              <td>{{ a.appId }}</td><td>{{ a.appName }}</td><td>{{ a.description }}</td>
              <td><span class="badge" [class.badge-active]="a.status==='ACTIVE'" [class.badge-inactive]="a.status!=='ACTIVE'">{{ a.status }}</span></td>
              <td>
                <button class="icon-btn" (click)="openAppForm(a)">✏️</button>
                <button class="icon-btn" (click)="deleteApp(a)">🗑️</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Users Tab -->
      <div class="content" *ngIf="tab==='users'">
        <div style="display:flex;gap:8px;margin-bottom:12px">
          <button class="tab-btn" [class.active]="userTab==='managers'" (click)="userTab='managers'">App Managers</button>
          <button class="tab-btn" [class.active]="userTab==='appusers'" (click)="userTab='appusers'">App Users</button>
          <button class="btn btn-primary" style="margin-left:auto" (click)="openUserForm(null)">+ Add User</button>
        </div>
        <div class="form-panel" *ngIf="showUserForm">
          <h3>{{ editUser ? 'Edit User' : 'New User' }}</h3>
          <div class="form-grid">
            <div class="form-group"><label>First Name</label><input [(ngModel)]="userForm.firstName"></div>
            <div class="form-group"><label>Last Name</label><input [(ngModel)]="userForm.lastName"></div>
            <div class="form-group"><label>Username</label><input [(ngModel)]="userForm.username" [disabled]="!!editUser"></div>
            <div class="form-group" *ngIf="!editUser"><label>Password</label><input type="password" [(ngModel)]="userForm.password"></div>
            <div class="form-group"><label>Email</label><input [(ngModel)]="userForm.email"></div>
            <div class="form-group"><label>Role</label>
              <select [(ngModel)]="userForm.role">
                <option value="APP_MANAGER">Application Manager</option>
                <option value="APP_USER">Application User</option>
              </select>
            </div>
          </div>
          <div class="form-actions">
            <button class="btn btn-primary" (click)="saveUser()">Save</button>
            <button class="btn btn-secondary" (click)="showUserForm=false">Cancel</button>
          </div>
        </div>
        <table class="data-table">
          <thead><tr><th>User ID</th><th>Name</th><th>Username</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            <tr *ngFor="let u of displayedUsers()">
              <td>{{ u.userId }}</td>
              <td>{{ u.firstName }} {{ u.lastName }}</td>
              <td>{{ u.username }}</td>
              <td>{{ u.status }}</td>
              <td>
                <button class="icon-btn" (click)="openUserForm(u)">✏️</button>
                <button class="icon-btn" (click)="deleteUser(u)">🗑️</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Assignments Tab -->
      <div class="content" *ngIf="tab==='assign'">
        <div class="form-group" style="max-width:300px">
          <label>Select Application</label>
          <select [(ngModel)]="assignApp" (change)="loadAssignments()">
            <option value="">-- Select --</option>
            <option *ngFor="let a of apps" [value]="a.appId">{{ a.appName }}</option>
          </select>
        </div>
        <div *ngIf="assignApp" style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:16px">
          <div class="panel">
            <h4>Managers</h4>
            <div class="assign-input">
              <select [(ngModel)]="newManagerId">
                <option value="">Select manager...</option>
                <option *ngFor="let u of allManagers" [value]="u.userId">{{ u.firstName }} {{ u.lastName }}</option>
              </select>
              <button class="btn btn-primary" (click)="doAssignManager()">Assign</button>
            </div>
            <table class="data-table" style="margin-top:8px">
              <thead><tr><th>User ID</th><th>Remove</th></tr></thead>
              <tbody>
                <tr *ngFor="let m of assignedManagers">
                  <td>{{ m.managerUserId }}</td>
                  <td><button class="icon-btn" (click)="doRemoveManager(m.managerUserId)">✖</button></td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="panel">
            <h4>Application Users</h4>
            <div class="assign-input">
              <select [(ngModel)]="newUserId">
                <option value="">Select user...</option>
                <option *ngFor="let u of allAppUsers" [value]="u.userId">{{ u.firstName }} {{ u.lastName }}</option>
              </select>
              <button class="btn btn-primary" (click)="doAssignUser()">Assign</button>
            </div>
            <table class="data-table" style="margin-top:8px">
              <thead><tr><th>User ID</th><th>Remove</th></tr></thead>
              <tbody>
                <tr *ngFor="let u of assignedUsers">
                  <td>{{ u.userId }}</td>
                  <td><button class="icon-btn" (click)="doRemoveUser(u.userId)">✖</button></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Help Tab -->
      <div class="content" *ngIf="tab==='help'">
        <h3>Help</h3>
        <iframe *ngIf="helpSrc" [src]="helpSrc" style="width:100%;height:600px;border:1px solid #ddd;border-radius:4px"></iframe>
      </div>
    </div>
  `,
  styles: [`
    .page { min-height:100vh; background:#f5f5f5; }
    .form-panel { background:white; padding:16px; border-radius:4px; margin-bottom:16px; border:1px solid #e0e0e0; }
    .form-grid { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
    .form-actions { display:flex; gap:8px; margin-top:12px; }
    .toolbar { display:flex; gap:8px; margin-bottom:12px; align-items:center; }
    .panel { background:white; padding:12px; border-radius:4px; }
    .assign-input { display:flex; gap:8px; }
    .assign-input select { flex:1; padding:6px; border:1px solid #ccc; border-radius:4px; }
    .badge { padding:2px 8px; border-radius:10px; font-size:0.75rem; }
    .badge-active { background:#e8f5e9; color:#2e7d32; }
    .badge-inactive { background:#ffebee; color:#c62828; }
  `]
})
export class ProjectOfficerComponent implements OnInit {
  tab = 'apps';
  userTab = 'managers';
  user: any = null;
  apps: any[] = [];
  users: any[] = [];
  appFilter = '';
  showAppForm = false;
  editApp: any = null;
  appForm: any = {};
  showUserForm = false;
  editUser: any = null;
  userForm: any = {};
  assignApp = '';
  assignedManagers: any[] = [];
  assignedUsers: any[] = [];
  allManagers: any[] = [];
  allAppUsers: any[] = [];
  newManagerId = '';
  newUserId = '';

  helpSrc: SafeResourceUrl | null = null;

  constructor(private auth: AuthService, private api: ApiService, private sanitizer: DomSanitizer) {}

  ngOnInit(): void {
    this.user = this.auth.getCurrentUser();
    this.loadApps();
    this.api.getHelp('PROJECT_OFFICER').subscribe({
      next: blob => { this.helpSrc = this.sanitizer.bypassSecurityTrustResourceUrl(URL.createObjectURL(blob)); },
      error: () => {}
    });
  }

  loadApps(): void { this.api.getApplications().subscribe({ next: a => this.apps = a }); }
  loadUsers(): void { this.api.getUsers().subscribe({ next: u => this.users = u }); }
  loadAllUsers(): void {
    this.api.getUsers('APP_MANAGER').subscribe({ next: u => this.allManagers = u });
    this.api.getUsers('APP_USER').subscribe({ next: u => this.allAppUsers = u });
  }

  filteredApps(): any[] {
    if (!this.appFilter) return this.apps;
    const f = this.appFilter.toLowerCase();
    return this.apps.filter(a => a.appName?.toLowerCase().includes(f) || a.appId?.toLowerCase().includes(f));
  }

  displayedUsers(): any[] {
    const role = this.userTab === 'managers' ? 'APP_MANAGER' : 'APP_USER';
    return this.users.filter(u => u.role === role);
  }

  openAppForm(a: any): void { this.editApp = a; this.appForm = a ? { ...a } : {}; this.showAppForm = true; }
  saveApp(): void {
    const obs = this.editApp
      ? this.api.updateApplication(this.editApp.appId, this.appForm)
      : this.api.createApplication(this.appForm);
    obs.subscribe({ next: () => { this.showAppForm = false; this.loadApps(); } });
  }
  deleteApp(a: any): void {
    if (!confirm(`Delete ${a.appName}?`)) return;
    this.api.deleteApplication(a.appId).subscribe({ next: () => this.loadApps() });
  }

  openUserForm(u: any): void { this.editUser = u; this.userForm = u ? { ...u } : { role: 'APP_MANAGER' }; this.showUserForm = true; }
  saveUser(): void {
    const obs = this.editUser
      ? this.api.updateUser(this.editUser.userId, this.userForm)
      : this.api.createUser(this.userForm);
    obs.subscribe({ next: () => { this.showUserForm = false; this.loadUsers(); } });
  }
  deleteUser(u: any): void {
    if (!confirm('Delete user?')) return;
    this.api.deleteUser(u.userId).subscribe({ next: () => this.loadUsers() });
  }

  loadAssignments(): void {
    if (!this.assignApp) return;
    this.api.getManagers(this.assignApp).subscribe({ next: m => this.assignedManagers = m });
    this.api.getAppUsers(this.assignApp).subscribe({ next: u => this.assignedUsers = u });
  }
  doAssignManager(): void {
    if (!this.newManagerId) return;
    this.api.assignManager(this.assignApp, this.newManagerId).subscribe({ next: () => { this.newManagerId = ''; this.loadAssignments(); } });
  }
  doRemoveManager(id: string): void { this.api.removeManager(this.assignApp, id).subscribe({ next: () => this.loadAssignments() }); }
  doAssignUser(): void {
    if (!this.newUserId) return;
    this.api.assignUser(this.assignApp, this.newUserId).subscribe({ next: () => { this.newUserId = ''; this.loadAssignments(); } });
  }
  doRemoveUser(id: string): void { this.api.removeUser(this.assignApp, id).subscribe({ next: () => this.loadAssignments() }); }

  logout(): void { this.auth.logout(); }
}
