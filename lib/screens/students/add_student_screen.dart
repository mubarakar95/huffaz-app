import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../providers/app_provider.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({Key? key}) : super(key: key);

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _contactController = TextEditingController();
  
  final _sabaqGoalController = TextEditingController();
  final _sabqiGoalController = TextEditingController();
  final _manzilGoalController = TextEditingController();

  String? _selectedTeacherId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    
    // Set default goals from provider
    _sabaqGoalController.text = provider.defaultSabaqGoal.toString();
    _sabqiGoalController.text = provider.defaultSabqiGoal.toString();
    _manzilGoalController.text = provider.defaultManzilGoal.toString();

    // If teacher, pre-select and disable teacher selection
    if (provider.profile?.role == 'teacher') {
      _selectedTeacherId = provider.user?.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentNameController.dispose();
    _contactController.dispose();
    _sabaqGoalController.dispose();
    _sabqiGoalController.dispose();
    _manzilGoalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();

      final name = _nameController.text.trim();
      final parentName = _parentNameController.text.trim().isEmpty ? null : _parentNameController.text.trim();
      final contactNumber = _contactController.text.trim().isEmpty ? null : _contactController.text.trim();
      
      final sGoal = double.tryParse(_sabaqGoalController.text.trim());
      final sqGoal = double.tryParse(_sabqiGoalController.text.trim());
      final mGoal = double.tryParse(_manzilGoalController.text.trim());

      final result = await provider.addStudent(
        fullName: name,
        parentName: parentName,
        contactNumber: contactNumber,
        teacherId: _selectedTeacherId,
        sabaqGoal: sGoal,
        sabqiGoal: sqGoal,
        manzilGoal: mGoal,
        isPersonal: false,
      );

      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $result'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get list of teachers from institution people
    final teachersList = List.from(provider.institutionPeople['teachers'] ?? []);
    final isTeacherRole = provider.profile?.role == 'teacher';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Add New Student'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textMainLight,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2F34) : const Color(0xFFF4F4F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Basic Info Card
                Card(
                  elevation: 0,
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Student Full Name *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter student name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _parentNameController,
                          decoration: const InputDecoration(
                            labelText: 'Parent/Guardian Name',
                            prefixIcon: Icon(Icons.people_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _contactController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Section 2: Administrative Card
                Card(
                  elevation: 0,
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Administrative Options',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedTeacherId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assign Teacher',
                            prefixIcon: Icon(Icons.assignment_ind_outlined),
                          ),
                          items: [
                            if (!isTeacherRole)
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Unassigned (Open for all)'),
                              ),
                            ...teachersList.map((t) => DropdownMenuItem<String>(
                                  value: t['id']?.toString(),
                                  child: Text(t['full_name']?.toString() ?? 'Teacher'),
                                )),
                          ],
                          onChanged: isTeacherRole
                              ? null // Disable change if teacher role
                              : (val) {
                                  setState(() {
                                    _selectedTeacherId = val;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Section 3: Goals Card
                Card(
                  elevation: 0,
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Custom Targets / Goals',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _sabaqGoalController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Custom Sabaq Goal (Pages)',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Please enter a valid page number';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _sabqiGoalController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Custom Sabaq Para Goal (Pages)',
                            prefixIcon: Icon(Icons.outlined_flag_rounded),
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Please enter a valid page number';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _manzilGoalController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Custom Muraja Goal (Pages)',
                            prefixIcon: Icon(Icons.album_outlined),
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Please enter a valid page number';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Add Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
