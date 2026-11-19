import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

SupabaseClient get supabase => Supabase.instance.client;
