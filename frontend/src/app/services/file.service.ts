import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface FileMeta {
  id: number;
  filename: string;
  contentType: string;
}

@Injectable({ providedIn: 'root' })
export class FileService {
  private api = '/api/files';

  constructor(private http: HttpClient) {}

  upload(file: File): Observable<FileMeta> {
    const form = new FormData();
    form.append('file', file);
    return this.http.post<FileMeta>(`${this.api}/upload`, form);
  }

  list(): Observable<FileMeta[]> {
    return this.http.get<FileMeta[]>(this.api);
  }

  downloadUrl(id: number): string {
    return `${this.api}/download/${id}`;
  }
}
