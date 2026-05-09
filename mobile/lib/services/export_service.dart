import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  
  static Future<void> exportToCSV(List<dynamic> sessions) async {
    List<List<dynamic>> rows = [];
    // Header
    rows.add(["Date", "Block", "Week", "Day", "Exercise", "Weight", "Sets", "Reps"]);
    
    for (var session in sessions) {
      final date = session['date']?.toString().split('T').first ?? '';
      final block = session['block']?.toString() ?? '';
      final week = session['week']?.toString() ?? '';
      final day = session['day']?.toString() ?? '';
      
      final exercises = session['exercises'] as List? ?? [];
      for (var ex in exercises) {
        final name = ex['name']?.toString() ?? '';
        final sets = ex['sets'] as List? ?? [];
        for (var st in sets) {
          final w = st['weight']?.toString() ?? '';
          final c = st['sets']?.toString() ?? '';
          final r = st['reps']?.toString() ?? '';
          
          rows.add([date, block, week, day, name, w, c, r]);
        }
      }
    }
    
    String csv = ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('\${dir.path}/training_history.csv');
    await file.writeAsString(csv);
    
    await Share.shareXFiles([XFile(file.path)], text: 'My SBD Training History');
  }

  static Future<void> exportToPDF(List<dynamic> sessions, Map<String, dynamic> prs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text("SBD Tracker Summary")),
              pw.SizedBox(height: 20),
              pw.Text("Current Maxes", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Bullet(text: "Squat: \${prs['Squat'] ?? 0} kg"),
              pw.Bullet(text: "Bench: \${prs['Bench'] ?? 0} kg"),
              pw.Bullet(text: "Deadlift: \${prs['Deadlift'] ?? 0} kg"),
              pw.SizedBox(height: 20),
              pw.Text("Total Sessions: \${sessions.length}", style: pw.TextStyle(fontSize: 16)),
            ]
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('\${dir.path}/training_summary.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'My Training Summary PDF');
  }
}
