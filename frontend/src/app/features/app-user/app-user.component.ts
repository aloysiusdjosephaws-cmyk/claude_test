import { Component, OnInit } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { AuthService } from '../../core/auth.service';
import { ApiService } from '../../core/api.service';

@Component({
  selector: 'app-user',
  standalone: true,
  imports: [CommonModule, FormsModule, DatePipe],
  template: `
    <div class="page">
      <div class="header">
        <span class="app-name">UDS ⚙</span>
        <div class="tabs">
          <button class="tab-btn" [class.active]="tab==='files'" (click)="tab='files'">Files</button>
          <button class="tab-btn" [class.active]="tab==='help'" (click)="tab='help'">Help</button>
        </div>
        <span class="user-name" (click)="logout()" style="cursor:pointer" title="Logout">
          {{ user?.firstName }} {{ user?.lastName }} ▾
        </span>
      </div>

      <div class="content" *ngIf="tab==='files'">
        <!-- App Selector -->
        <div class="form-group" style="max-width:320px;margin-bottom:20px">
          <label>Select Application</label>
          <select [(ngModel)]="selectedAppId" (change)="onAppChange()">
            <option value="">-- Select Application --</option>
            <option *ngFor="let a of apps" [value]="a.appId">{{ a.appName }}</option>
          </select>
        </div>

        <!-- Search Form -->
        <div class="search-panel" *ngIf="selectedAppId">
          <h3>Search Documents</h3>
          <div class="search-grid">
            <div class="form-group">
              <label>Key ID</label>
              <input [(ngModel)]="search.keyId" placeholder="Optional">
            </div>
            <div class="form-group">
              <label>Document Name</label>
              <input [(ngModel)]="search.docName" placeholder="Optional">
            </div>
            <div class="form-group">
              <label>Group</label>
              <select [(ngModel)]="search.groupName">
                <option value="">-- All Groups --</option>
                <option *ngFor="let g of groups" [value]="g.groupName">{{ g.groupName }}</option>
              </select>
            </div>
            <div class="form-group" style="display:flex;align-items:flex-end">
              <button class="btn btn-primary" (click)="doSearch()">Search</button>
            </div>
          </div>
        </div>

        <!-- Results -->
        <div *ngIf="results.length > 0" style="margin-top:16px">
          <h3>Results ({{ results.length }})</h3>
          <table class="data-table">
            <thead>
              <tr>
                <th>ID</th><th>Group</th><th>Extension</th><th>File Name</th>
                <th>Upload Date</th><th>Description</th><th>Size</th><th>Download</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let d of results">
                <td>{{ d.id }}</td>
                <td>{{ d.groupName }}</td>
                <td>{{ d.extension }}</td>
                <td>{{ d.docName }}</td>
                <td>{{ d.uploadDate | date:'short' }}</td>
                <td>{{ d.description }}</td>
                <td>{{ formatSize(d.fileSize) }}</td>
                <td><button class="btn btn-primary" style="padding:4px 10px;font-size:0.8rem" (click)="download(d)">⬇ Download</button></td>
              </tr>
            </tbody>
          </table>
        </div>

        <div *ngIf="searched && results.length===0" style="margin-top:16px;color:#888">No documents found matching your criteria.</div>
      </div>

      <div class="content" *ngIf="tab==='help'">
        <iframe *ngIf="helpSrc" [src]="helpSrc" style="width:100%;height:600px;border:1px solid #ddd;border-radius:4px"></iframe>
      </div>
    </div>
  `,
  styles: [`
    .page { min-height:100vh; background:#f5f5f5; }
    .search-panel { background:white; padding:16px; border-radius:4px; border:1px solid #e0e0e0; }
    .search-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; }
  `]
})
export class AppUserComponent implements OnInit {
  tab = 'files';
  user: any = null;
  apps: any[] = [];
  groups: any[] = [];
  results: any[] = [];
  selectedAppId = '';
  search = { keyId: '', docName: '', groupName: '' };
  searched = false;

  helpSrc: SafeResourceUrl | null = null;

  constructor(private auth: AuthService, private api: ApiService, private sanitizer: DomSanitizer) {}

  ngOnInit(): void {
    this.user = this.auth.getCurrentUser();
    this.api.getApplications().subscribe({ next: a => this.apps = a });
    this.api.getHelp('APP_USER').subscribe({
      next: blob => { this.helpSrc = this.sanitizer.bypassSecurityTrustResourceUrl(URL.createObjectURL(blob)); },
      error: () => {}
    });
  }

  onAppChange(): void {
    this.results = [];
    this.searched = false;
    if (this.selectedAppId) {
      this.api.getGroups(this.selectedAppId).subscribe({ next: g => this.groups = g });
    }
  }

  doSearch(): void {
    this.api.searchDocuments(
      this.selectedAppId,
      this.search.keyId || undefined,
      this.search.docName || undefined,
      this.search.groupName || undefined
    ).subscribe({ next: r => { this.results = r; this.searched = true; } });
  }

  download(d: any): void { this.api.downloadDocument(d.id); }

  formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
  }

  logout(): void { this.auth.logout(); }
}
