import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private base = environment.apiUrl;

  constructor(private http: HttpClient) {}

  // Users
  getUsers(role?: string): Observable<any[]> {
    const params = role ? `?role=${role}` : '';
    return this.http.get<any[]>(`${this.base}/users${params}`);
  }
  createUser(data: any): Observable<any> { return this.http.post(`${this.base}/users`, data); }
  updateUser(userId: string, data: any): Observable<any> { return this.http.put(`${this.base}/users/${userId}`, data); }
  deleteUser(userId: string): Observable<any> { return this.http.delete(`${this.base}/users/${userId}`); }
  getMe(): Observable<any> { return this.http.get(`${this.base}/users/me`); }

  // Applications
  getApplications(): Observable<any[]> { return this.http.get<any[]>(`${this.base}/applications`); }
  createApplication(data: any): Observable<any> { return this.http.post(`${this.base}/applications`, data); }
  updateApplication(appId: string, data: any): Observable<any> { return this.http.put(`${this.base}/applications/${appId}`, data); }
  deleteApplication(appId: string): Observable<any> { return this.http.delete(`${this.base}/applications/${appId}`); }
  getManagers(appId: string): Observable<any[]> { return this.http.get<any[]>(`${this.base}/applications/${appId}/managers`); }
  assignManager(appId: string, userId: string): Observable<any> { return this.http.post(`${this.base}/applications/${appId}/managers`, { userId }); }
  removeManager(appId: string, userId: string): Observable<any> { return this.http.delete(`${this.base}/applications/${appId}/managers/${userId}`); }
  getAppUsers(appId: string): Observable<any[]> { return this.http.get<any[]>(`${this.base}/applications/${appId}/users`); }
  assignUser(appId: string, userId: string): Observable<any> { return this.http.post(`${this.base}/applications/${appId}/users`, { userId }); }
  removeUser(appId: string, userId: string): Observable<any> { return this.http.delete(`${this.base}/applications/${appId}/users/${userId}`); }

  // Documents
  getDocuments(appId: string): Observable<any[]> { return this.http.get<any[]>(`${this.base}/documents?appId=${appId}`); }
  uploadDocument(formData: FormData): Observable<any> { return this.http.post(`${this.base}/documents/upload`, formData); }
  updateDocument(id: number, data: any): Observable<any> { return this.http.put(`${this.base}/documents/${id}`, data); }
  deleteDocument(id: number): Observable<any> { return this.http.delete(`${this.base}/documents/${id}`); }
  downloadDocument(id: number): void {
    const token = localStorage.getItem('auth_token');
    const url = `${this.base}/documents/${id}/download`;
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
    let url = `${this.base}/documents/search?appId=${appId}`;
    if (keyId) url += `&keyId=${keyId}`;
    if (docName) url += `&docName=${docName}`;
    if (groupName) url += `&groupName=${groupName}`;
    return this.http.get<any[]>(url);
  }

  // Groups
  getGroups(appId: string): Observable<any[]> { return this.http.get<any[]>(`${this.base}/groups?appId=${appId}`); }
  createGroup(appId: string, groupName: string): Observable<any> { return this.http.post(`${this.base}/groups`, { appId, groupName }); }
  updateGroup(id: number, groupName: string): Observable<any> { return this.http.put(`${this.base}/groups/${id}`, { groupName }); }

  // Help
  getHelp(screenName: string): Observable<Blob> { return this.http.get(`${this.base}/help/${screenName}`, { responseType: 'blob' }); }
  uploadHelp(screenName: string, formData: FormData): Observable<any> { return this.http.put(`${this.base}/help/${screenName}`, formData); }

  // Audit
  getAuditEvents(params: any): Observable<any> { return this.http.get(`${this.base}/audit/events`, { params }); }
}
