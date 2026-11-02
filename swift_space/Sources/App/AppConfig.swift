import Foundation

enum AppConfig {
    // Ambos valores son públicos por diseño: la seguridad la aplica RLS en la base de datos.
    static let supabaseURL = URL(string: "https://rxvqsvjbtteejrrzfpoh.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4dnFzdmpidHRlZWpycnpmcG9oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM2MzYzMTYsImV4cCI6MjEwOTIxMjMxNn0.TlibVOz362jR_vQv8CP8zbby1CZB9u5E9Ry4cuaN0d8"
}
