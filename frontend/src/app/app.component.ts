import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FileService, FileMeta } from './services/file.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit {
  files: FileMeta[] = [];
  uploading = false;
  message = '';
  error = '';

  constructor(private fileService: FileService) {}

  ngOnInit(): void {
    this.loadFiles();
  }

  loadFiles(): void {
    this.fileService.list().subscribe({
      next: files => this.files = files,
      error: () => this.error = 'Failed to load files.'
    });
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;
    const file = input.files[0];
    this.uploading = true;
    this.message = '';
    this.error = '';

    this.fileService.upload(file).subscribe({
      next: meta => {
        this.message = `Uploaded "${meta.filename}" (id: ${meta.id})`;
        this.uploading = false;
        input.value = '';
        this.loadFiles();
      },
      error: () => {
        this.error = 'Upload failed.';
        this.uploading = false;
      }
    });
  }

  downloadUrl(id: number): string {
    return this.fileService.downloadUrl(id);
  }
}
