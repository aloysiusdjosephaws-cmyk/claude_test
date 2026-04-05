import { Component, OnInit } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { AuthService } from '../../core/auth.service';
import { ApiService } from '../../core/api.service';

@Component({
  selector: 'app-manager',
  standalone: true,
  imports: [CommonModule, FormsModule, DatePipe],
  template: `
    <div class="page-layout">
      <!-- Left Panel -->
      <div class="left-panel" [class.collapsed]="panelCollapsed">
        <button class="collapse-btn" (click)="panelCollapsed=!panelCollapsed">
          {{ panelCollapsed ? '▶' : '◀' }}
        </button>
        <div class="panel-content" *ngIf="!panelCollapsed">

          <!-- File Details (edit selected document) -->
          <div class="section">
            <div class="section-header" (click)="sec.details=!sec.details">
              File Details <span>{{ sec.details ? '▲' : '▼' }}</span>
            </div>
            <div *ngIf="sec.details">
              <div class="form-group">
                <label>Description</label>
                <textarea [(ngModel)]="detailForm.description" maxlength="255" rows="3"></textarea>
                <div class="char-counter">{{ (detailForm.description||'').length }}/255</div>
              </div>
              <div class="form-group">
                <label>Group</label>
                <input [(ngModel)]="detailForm.groupName" maxlength="100">
                <div class="char-counter">{{ (detailForm.groupName||'').length }}/100</div>
              </div>
              <button class="btn btn-primary" style="width:100%" (click)="saveDetails()" [disabled]="!selectedDoc">Save</button>
            </div>
          </div>

          <!-- File Group -->
          <div class="section">
            <div class="section-header" (click)="sec.group=!sec.group">
              File Group <span>{{ sec.group ? '▲' : '▼' }}</span>
            </div>
            <div *ngIf="sec.group">
              <div class="form-group">
                <label>Group Name</label>
                <input [(ngModel)]="newGroup" maxlength="100">
                <div class="char-counter">{{ (newGroup||'').length }}/100</div>
              </div>
              <button class="btn btn-primary" style="width:100%" (click)="createGroup()">Save</button>
            </div>
          </div>

          <!-- Files to be changed -->
          <div class="section-label">Files to be changed: {{ selectedDoc ? 1 : 0 }}</div>

          <!-- File Upload -->
          <div class="section">
            <div class="section-header" (click)="sec.upload=!sec.upload">
              File Upload <span>{{ sec.upload ? '▲' : '▼' }}</span>
            </div>
            <div *ngIf="sec.upload">
              <div class="form-group">
                <input type="file" #fileInput (change)="onFileSelected($event)" style="display:none">
                <div class="file-name" (click)="fileInput.click()">{{ uploadFile ? uploadFile.name : 'Please select a file' }}</div>
              </div>
              <div class="form-group">
                <label>Description</label>
                <input [(ngModel)]="uploadForm.description" maxlength="255">
                <div class="char-counter">{{ (uploadForm.description||'').length }}/255</div>
              </div>
              <div class="form-group">
                <label>Group</label>
                <select [(ngModel)]="uploadForm.groupName">
                  <option value="">-- None --</option>
                  <option *ngFor="let g of groups" [value]="g.groupName">{{ g.groupName }}</option>
                </select>
              </div>
              <div class="form-group">
                <label>File Filter</label>
                <select [(ngModel)]="uploadForm.fileFilter">
                  <option value="N">N (Visible to all)</option>
                  <option value="Y">Y (Uploader only)</option>
                </select>
              </div>
              <div style="display:flex;gap:8px">
                <button class="btn btn-secondary" (click)="fileInput.click()">Select File</button>
                <button class="btn btn-primary" (click)="uploadDocument()" [disabled]="!uploadFile || uploading">
                  {{ uploading ? 'Uploading...' : 'Upload' }}
                </button>
              </div>
              <div class="error-msg" *ngIf="uploadError">{{ uploadError }}</div>
            </div>
          </div>

          <!-- Applications List -->
          <div class="section">
            <div class="section-header" (click)="sec.apps=!sec.apps">
              Applications <span>{{ sec.apps ? '▲' : '▼' }}</span>
            </div>
            <div *ngIf="sec.apps">
              <div class="app-item" *ngFor="let a of apps"
                   [class.selected]="selectedApp?.appId===a.appId"
                   (click)="selectApp(a)">
                {{ a.appName }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Panel -->
      <div class="main-panel">
        <!-- Header -->
        <div class="header">
          <span class="app-name">{{ selectedApp?.appName || 'Application Manager' }} ⚙</span>
          <div class="tabs">
            <button class="tab-btn" [class.active]="mainTab==='files'" (click)="mainTab='files'">Files</button>
            <button class="tab-btn" [class.active]="mainTab==='help'" (click)="mainTab='help'">Help</button>
          </div>
          <span class="user-name" (click)="logout()" style="cursor:pointer" title="Logout">
            {{ user?.firstName }} {{ user?.lastName }} ▾
          </span>
        </div>

        <!-- Files View -->
        <div class="panel-body" *ngIf="mainTab==='files'">
          <div *ngIf="!selectedApp" class="no-app">Select an application from the left panel.</div>
          <div *ngIf="selectedApp">
            <div class="filter-row">
              <input class="filter-input" [(ngModel)]="docFilter" placeholder="Filter..." (input)="applyFilter()">
              <span style="margin-left:auto;font-size:0.85rem;color:#888">Items per page:
                <select [(ngModel)]="pageSize" (change)="page=0" style="margin-left:4px">
                  <option [value]="10">10</option>
                  <option [value]="25">25</option>
                  <option [value]="50">50</option>
                </select>
              </span>
            </div>
            <table class="data-table">
              <thead>
                <tr>
                  <th>ID</th><th>Download</th><th>Group</th><th>Extension</th>
                  <th>File Name</th><th>Upload Date</th><th>Description</th><th>Size</th><th>Filter</th><th>Delete</th><th>Update</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let d of pagedDocs()"
                    [class.selected]="selectedDoc?.id===d.id"
                    (click)="selectDoc(d)">
                  <td>{{ d.id }}</td>
                  <td><button class="icon-btn" (click)="download(d,$event)" title="Download">⬇</button></td>
                  <td>{{ d.groupName }}</td>
                  <td>{{ d.extension }}</td>
                  <td>{{ d.docName }}</td>
                  <td>{{ d.uploadDate | date:'short' }}</td>
                  <td>{{ d.description }}</td>
                  <td>{{ formatSize(d.fileSize) }}</td>
                  <td>{{ d.fileFilter }}</td>
                  <td><button class="icon-btn" (click)="deleteDoc(d,$event)" title="Delete">🗑️</button></td>
                  <td><button class="icon-btn" (click)="editDoc(d,$event)" title="Edit">✏️</button></td>
                </tr>
                <tr *ngIf="pagedDocs().length===0">
                  <td colspan="11" style="text-align:center;color:#888">No documents found.</td>
                </tr>
              </tbody>
            </table>
            <div class="pagination">
              <button class="icon-btn" (click)="page=0" [disabled]="page===0">⏮</button>
              <button class="icon-btn" (click)="page=page-1" [disabled]="page===0">◀</button>
              <span>{{ page+1 }} of {{ totalPages() }}</span>
              <button class="icon-btn" (click)="page=page+1" [disabled]="page>=totalPages()-1">▶</button>
              <button class="icon-btn" (click)="page=totalPages()-1" [disabled]="page>=totalPages()-1">⏭</button>
            </div>
          </div>
        </div>

        <!-- Help View -->
        <div class="panel-body" *ngIf="mainTab==='help'">
          <iframe *ngIf="helpSrc" [src]="helpSrc" style="width:100%;height:calc(100vh - 80px);border:none"></iframe>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .page-layout { display:flex; height:100vh; overflow:hidden; background:#f5f5f5; }
    .left-panel { width:230px; min-width:230px; background:#f0f0f0; border-right:1px solid #ddd; overflow-y:auto; position:relative; transition:width 0.2s; }
    .left-panel.collapsed { width:32px; min-width:32px; }
    .collapse-btn { position:absolute; right:0; top:50%; transform:translateY(-50%); background:#1a237e; color:white; border:none; width:20px; height:40px; cursor:pointer; z-index:10; border-radius:4px 0 0 4px; font-size:0.7rem; }
    .panel-content { padding:8px 8px 8px 8px; }
    .section { margin-bottom:8px; }
    .section-header { display:flex; justify-content:space-between; cursor:pointer; padding:6px 4px; background:#e0e0e0; border-radius:4px; font-size:0.82rem; font-weight:bold; }
    .section-label { font-size:0.8rem; font-weight:bold; padding:6px 4px; color:#555; }
    .file-name { padding:6px; border:1px dashed #ccc; border-radius:4px; font-size:0.8rem; cursor:pointer; color:#555; min-height:32px; }
    .app-item { padding:6px 4px; cursor:pointer; font-size:0.82rem; border-radius:4px; border-bottom:1px solid #ddd; }
    .app-item:hover, .app-item.selected { background:#c5cae9; }
    .main-panel { flex:1; display:flex; flex-direction:column; overflow:hidden; }
    .panel-body { flex:1; padding:12px; overflow:auto; }
    .filter-row { display:flex; align-items:center; gap:8px; margin-bottom:10px; }
    .no-app { display:flex; align-items:center; justify-content:center; height:200px; color:#888; font-size:1rem; }
    .error-msg { color:#c62828; font-size:0.8rem; margin-top:6px; }
  `]
})
export class AppManagerComponent implements OnInit {
  user: any = null;
  apps: any[] = [];
  groups: any[] = [];
  docs: any[] = [];
  filteredDocs: any[] = [];
  selectedApp: any = null;
  selectedDoc: any = null;
  mainTab = 'files';
  panelCollapsed = false;
  docFilter = '';
  page = 0;
  pageSize = 10;
  uploading = false;
  uploadFile: File | null = null;
  uploadError = '';
  newGroup = '';
  sec = { details: true, group: true, upload: true, apps: true };
  detailForm: any = {};
  uploadForm: any = { fileFilter: 'N' };

  helpSrc: SafeResourceUrl | null = null;

  constructor(private auth: AuthService, private api: ApiService, private sanitizer: DomSanitizer) {}

  ngOnInit(): void {
    this.user = this.auth.getCurrentUser();
    this.api.getApplications().subscribe({ next: a => { this.apps = a; if (a.length) this.selectApp(a[0]); } });
    this.api.getHelp('APP_MANAGER').subscribe({
      next: blob => { this.helpSrc = this.sanitizer.bypassSecurityTrustResourceUrl(URL.createObjectURL(blob)); },
      error: () => {}
    });
  }

  selectApp(app: any): void {
    this.selectedApp = app;
    this.selectedDoc = null;
    this.detailForm = {};
    this.page = 0;
    this.api.getDocuments(app.appId).subscribe({ next: d => { this.docs = d; this.applyFilter(); } });
    this.api.getGroups(app.appId).subscribe({ next: g => this.groups = g });
  }

  applyFilter(): void {
    if (!this.docFilter) { this.filteredDocs = [...this.docs]; return; }
    const f = this.docFilter.toLowerCase();
    this.filteredDocs = this.docs.filter(d =>
      d.docName?.toLowerCase().includes(f) ||
      d.groupName?.toLowerCase().includes(f) ||
      d.description?.toLowerCase().includes(f) ||
      d.extension?.toLowerCase().includes(f)
    );
    this.page = 0;
  }

  pagedDocs(): any[] {
    const start = this.page * this.pageSize;
    return this.filteredDocs.slice(start, start + this.pageSize);
  }

  totalPages(): number { return Math.max(1, Math.ceil(this.filteredDocs.length / this.pageSize)); }

  selectDoc(d: any): void {
    this.selectedDoc = d;
    this.detailForm = { description: d.description, groupName: d.groupName };
  }

  editDoc(d: any, e: Event): void { e.stopPropagation(); this.selectDoc(d); this.sec.details = true; }

  saveDetails(): void {
    if (!this.selectedDoc) return;
    this.api.updateDocument(this.selectedDoc.id, this.detailForm).subscribe({
      next: () => this.selectApp(this.selectedApp)
    });
  }

  download(d: any, e: Event): void { e.stopPropagation(); this.api.downloadDocument(d.id); }

  deleteDoc(d: any, e: Event): void {
    e.stopPropagation();
    if (!confirm(`Delete "${d.docName}"?`)) return;
    this.api.deleteDocument(d.id).subscribe({ next: () => this.selectApp(this.selectedApp) });
  }

  onFileSelected(e: Event): void {
    const input = e.target as HTMLInputElement;
    this.uploadFile = input.files?.[0] ?? null;
  }

  uploadDocument(): void {
    if (!this.uploadFile || !this.selectedApp) return;
    this.uploading = true;
    this.uploadError = '';
    const fd = new FormData();
    fd.append('file', this.uploadFile);
    fd.append('appId', this.selectedApp.appId);
    if (this.uploadForm.description) fd.append('description', this.uploadForm.description);
    if (this.uploadForm.groupName) fd.append('groupName', this.uploadForm.groupName);
    fd.append('fileFilter', this.uploadForm.fileFilter || 'N');
    this.api.uploadDocument(fd).subscribe({
      next: () => {
        this.uploading = false;
        this.uploadFile = null;
        this.uploadForm = { fileFilter: 'N' };
        this.selectApp(this.selectedApp);
      },
      error: () => { this.uploading = false; this.uploadError = 'Upload failed.'; }
    });
  }

  createGroup(): void {
    if (!this.newGroup || !this.selectedApp) return;
    this.api.createGroup(this.selectedApp.appId, this.newGroup).subscribe({
      next: () => { this.newGroup = ''; this.api.getGroups(this.selectedApp.appId).subscribe({ next: g => this.groups = g }); }
    });
  }

  formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
  }

  logout(): void { this.auth.logout(); }
}
