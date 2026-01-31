// D:\ttu_housing_app\lib\screens\report_complaint_screen.dart

import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../models/models.dart';
import '../services/complaint_service.dart';

enum ReportTarget { apartment, owner }

class ReportComplaintScreen extends StatefulWidget {
  final ReportTarget target;
  final Apartment apartment;

  const ReportComplaintScreen({
    super.key,
    required this.target,
    required this.apartment,
  });

  @override
  State<ReportComplaintScreen> createState() => _ReportComplaintScreenState();
}

class _ReportComplaintScreenState extends State<ReportComplaintScreen> {
  final _descCtrl = TextEditingController();
  bool _loading = false;

  String _reason = 'other';

  List<DropdownMenuItem<String>> _reasons(BuildContext context) => [
    DropdownMenuItem(
      value: 'scam',
      child: Text(tr(context, 'Scam/Fraud', 'احتيال/نصب')),
    ),
    DropdownMenuItem(
      value: 'price',
      child: Text(tr(context, 'Unfair price', 'سعر غير منطقي')),
    ),
    DropdownMenuItem(
      value: 'spam',
      child: Text(tr(context, 'Spam', 'إعلان مزعج')),
    ),
    DropdownMenuItem(
      value: 'wrong_info',
      child: Text(tr(context, 'Wrong information', 'معلومات خاطئة')),
    ),
    DropdownMenuItem(value: 'other', child: Text(tr(context, 'Other', 'أخرى'))),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Please write details.', 'اكتب تفاصيل الشكوى.'),
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final svc = ComplaintService();
      if (widget.target == ReportTarget.apartment) {
        await svc.createApartmentComplaint(
          apartment: widget.apartment,
          reason: _reason,
          description: desc,
        );
      } else {
        await svc.createOwnerComplaint(
          ownerId: widget.apartment.ownerId,
          reason: _reason,
          description: desc,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Complaint submitted.', 'تم إرسال الشكوى.'),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Failed: $e', 'فشل: $e'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.target == ReportTarget.apartment
        ? tr(context, 'Report Apartment', 'الإبلاغ عن الشقة')
        : tr(context, 'Report Owner', 'الإبلاغ عن المالك');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(context, 'Reason', 'السبب')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _reason,
            items: _reasons(context),
            onChanged: (v) => setState(() => _reason = v ?? 'other'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Text(tr(context, 'Details', 'التفاصيل')),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 6,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: tr(
                context,
                'Write what happened...',
                'اكتب تفاصيل المشكلة...',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.report_gmailerrorred),
            label: Text(tr(context, 'Submit', 'إرسال')),
          ),
        ],
      ),
    );
  }
}
