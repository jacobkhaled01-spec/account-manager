import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../domain/models/template_rule.dart';

/// State of templates
class TemplatesState {
  final List<TemplateRule> templates;
  final bool isLoading;

  const TemplatesState({
    required this.templates,
    this.isLoading = false,
  });

  List<TemplateRule> get incomingTemplates =>
      templates.where((t) => t.type == TemplateType.incoming).toList();

  List<TemplateRule> get outgoingTemplates =>
      templates.where((t) => t.type == TemplateType.outgoing).toList();

  List<TemplateRule> get activeIncoming =>
      incomingTemplates.where((t) => t.isEnabled).toList();

  List<TemplateRule> get activeOutgoing =>
      outgoingTemplates.where((t) => t.isEnabled).toList();

  TemplatesState copyWith({
    List<TemplateRule>? templates,
    bool? isLoading,
  }) {
    return TemplatesState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing templates state
class TemplatesNotifier extends StateNotifier<TemplatesState> {
  final LocalStorageService _storage;

  TemplatesNotifier(this._storage)
      : super(TemplatesState(templates: _storage.getAllTemplates()));

  void refresh() {
    final list = _storage.getAllTemplates();
    state = state.copyWith(templates: list);
  }

  Future<void> addTemplate(TemplateRule template) async {
    await _storage.saveTemplate(template);
    refresh();
  }

  Future<void> updateTemplate(TemplateRule template) async {
    await _storage.saveTemplate(template);
    refresh();
  }

  Future<bool> deleteTemplate(String id) async {
    final success = await _storage.deleteTemplate(id);
    if (success) {
      refresh();
    }
    return success;
  }

  Future<void> toggleTemplate(String id, bool isEnabled) async {
    await _storage.toggleTemplate(id, isEnabled);
    refresh();
  }

  Future<void> resetToDefaults() async {
    await _storage.resetTemplatesToDefaults();
    refresh();
  }
}

/// Provider for templates management
final templatesProvider =
    StateNotifierProvider<TemplatesNotifier, TemplatesState>((ref) {
  return TemplatesNotifier(LocalStorageService.instance);
});
