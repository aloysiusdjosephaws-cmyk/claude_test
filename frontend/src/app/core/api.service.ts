import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class ApiService {
  constructor(private http: HttpClient) {}

  // Users
  getUsers(role?: string): Observable<any[]> {
    const params = role ? `?role=${role}` : '';
    return this.http.get<any[]>(`/api/users/${params}`);
  }
  createUser(data: any): Observable<any> { return this.http.post('/api/users/', data); }
  updateUser(userId: string, data: any): Observable<any> { return this.http.put(`/api/users/${userId}`, data); }
  deleteUser(userId: string): Observable<any> { return this.http.delete(`/api/users/${userId}`); }
  getMe(): Observable<any> { return this.http.get('/api/users/me'); }

  // Applications
  getApplications(): Observable<any[]> { return this.http.get<any[]>('/api/applications/'); }
  createApplication(data: any): Observable<any> { return this.http.post('/api/applications/', data); }
  updateApplication(appId: string, data: any): Observable<any> { return this.http.put(`/api/applications/${appId}`, data); }
  deleteApplication(appId: string): Observable<any> { return this.http.delete(`/api/applications/${appId}`); }
  getManagers(appId: string): Observable<any[]> { return this.http.get<any[]>(`/api/applications/${appId}/managers`); }
  assignManager(appId: string, userId: string): Observable<any> { return this.http.post(`/api/applications/${appId}/managers`, { userId }); }
  removeManager(appId: string, userId: string): Observable<any> { return this.http.delete(`/api/applications/${appId}/managers/${userId}`); }
  getAppUsers(appId: string): Observable<any[]> { return this.http.get<any[]>(`/api/applications/${appId}/users`); }
  assignUser(appId: string, userId: string): Observable<any> { return this.http.post(`/api/applications/${appId}/users`, { userId }); }
  removeUser(appId: string, userId: string): Observable<any> { return this.http.delete(`/api/applications/${appId}/users/${userId}`); }

  // Documents
  getDocuments(appId: string): Observable<any[]> { return this.http.get<any[]>(`/api/documents?appId=${appId}`); }
  uploadDocument(formData: FormData): Observable<any> { return this.http.post('/api/documents/upload', formData); }
  updateDocument(id: number, data: any): Observable<any> { return this.http.put(`/api/documents/${id}`, data); }
  deleteDocument(id: number): Observable<any> { return this.http.delete(`/api/documents/${id}`); }
  downloadDocument(id: number): void {
    const token = localStorage.getItem('auth_token');
    const url = `/api/documents/${id}/download`;
    fetch(url, { headers: { Authorization: `Bearer ${token}` } })
      .then(res => res.blob())
      .then(blob => {
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = `document-${id}`;
        a.click();
        URL.revokeObjectURL(a.href);
      });
  }
  searchDocuments(appId: string, keyId?: string, docName?: string, groupName?: string): Observable<any[]> {
    let url = `/api/documents/search?appId=${appId}`;
    if (keyId) url += `&keyId=${keyId}`;
    if (docName) url += `&docName=${docName}`;
    if (groupName) url += `&groupName=${groupName}`;
    return this.http.get<any[]>(url);
  }

  // Groups
  getGroups(appId: string): Observable<any[]> { return this.http.get<any[]>(`/api/groups?appId=${appId}`); }
  createGroup(appId: string, groupName: string): Observable<any> { return this.http.post('/api/groups/', { appId, groupName }); }
  updateGroup(id: number, groupName: string): Observable<any> { return this.http.put(`/api/groups/${id}`, { groupName }); }

  // Help
  getHelp(screenName: string): Observable<Blob> { return this.http.get(`/api/help/${screenName}`, { responseType: 'blob' }); }
  uploadHelp(screenName: string, formData: FormData): Observable<any> { return this.http.put(`/api/help/${screenName}`, formData); }

  // Audit
  getAuditEvents(params: any): Observable<any> { return this.http.get('/api/audit/events', { params }); }
}
