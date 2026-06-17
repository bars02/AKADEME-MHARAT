import { resolve } from 'path';
import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        login: resolve(__dirname, 'login.html'),
        register: resolve(__dirname, 'register.html'),
        student: resolve(__dirname, 'dashboard/student.html'),
        academic: resolve(__dirname, 'dashboard/academic.html'),
        admin: resolve(__dirname, 'dashboard/admin.html'),
        super_admin: resolve(__dirname, 'dashboard/super_admin.html'),
        check_email: resolve(__dirname, 'pages/check-email.html'),
        course_details: resolve(__dirname, 'pages/course-details.html'),
        waiting_approval: resolve(__dirname, 'pages/waiting-approval.html')
      }
    }
  }
});
