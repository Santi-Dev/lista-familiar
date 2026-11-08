import Foundation

enum AppConfig {
    // Ambos valores son públicos por diseño: la seguridad la aplica RLS en la base de datos.
    // Nunca pongas aquí la clave `service_role`.
    static let supabaseURL = URL(string: "https://rxvqsvjbtteejrrzfpoh.supabase.co")!
    /// Páginas públicas de `site/` (GitHub Pages, workflow `pages`).
    static let privacyURL = URL(string: "https://santi-dev.github.io/lista-familiar/privacidad.html")!
    /// A donde lleva el enlace del correo de «Olvidé mi contraseña» (hay que añadirla en Supabase →
    /// Authentication → URL Configuration → Redirect URLs).
    static let passwordResetURL = URL(string: "https://santi-dev.github.io/lista-familiar/recuperar.html")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4dnFzdmpidHRlZWpycnpmcG9oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM2MzYzMTYsImV4cCI6MjEwOTIxMjMxNn0.TlibVOz362jR_vQv8CP8zbby1CZB9u5E9Ry4cuaN0d8"
}
