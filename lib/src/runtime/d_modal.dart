import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

/// A reusable modal component for dialogs and forms.
///
/// Usage:
/// ```dart
/// DModal(
///   id: 'my-modal',
///   title: 'Edit Item',
///   child: MyForm(),
///   actions: [
///     button(classes: 'btn-cancel', [text('Cancel')]),
///     button(classes: 'btn-save', [text('Save')]),
///   ],
/// )
/// ```
///
/// To show/hide via JavaScript:
/// ```javascript
/// document.getElementById('my-modal').classList.add('active');
/// document.getElementById('my-modal').classList.remove('active');
/// ```
class DModal extends StatelessComponent {
  final String id;
  final String? title;
  final Component child;
  final List<Component>? actions;
  final String? maxWidth;
  final bool closeOnBackdrop;

  const DModal({
    super.key,
    required this.id,
    this.title,
    required this.child,
    this.actions,
    this.maxWidth,
    this.closeOnBackdrop = true,
  });

  @override
  Component build(BuildContext context) {
    final width = maxWidth ?? 'max-w-lg';

    // Modal backdrop and container
    return div(
      id: id,
      classes: 'fixed inset-0 z-50 hidden items-center justify-center',
      [
        // Backdrop
        div(
          classes: 'absolute inset-0 bg-black/60 backdrop-blur-sm',
          attributes: closeOnBackdrop
              ? {'onclick': "document.getElementById('$id').classList.add('hidden');document.getElementById('$id').classList.remove('flex');"}
              : {},
          [],
        ),
        // Modal content
        div(
          classes: '$width w-full mx-4 bg-gray-800 rounded-xl shadow-2xl border border-gray-700 relative z-10',
          [
            // Header
            if (title != null)
              div(classes: 'flex items-center justify-between p-4 border-b border-gray-700', [
                h3(classes: 'text-lg font-semibold text-white', [Component.text(title!)]),
                button(
                  classes: 'text-gray-400 hover:text-white p-1 rounded hover:bg-gray-700',
                  attributes: {'onclick': "document.getElementById('$id').classList.add('hidden');document.getElementById('$id').classList.remove('flex');"},
                  [Component.text('✕')],
                ),
              ]),
            // Body
            div(classes: 'p-4', [child]),
            // Actions
            if (actions != null && actions!.isNotEmpty)
              div(classes: 'flex justify-end gap-2 p-4 border-t border-gray-700', actions!),
          ],
        ),
        // CSS for active state (inline style tag)
        RawText('''<style>
          #$id.flex { display: flex !important; }
          #$id.hidden { display: none !important; }
        </style>'''),
      ],
    );
  }

  /// Returns JavaScript to open this modal
  static String openScript(String modalId) =>
      "document.getElementById('$modalId').classList.remove('hidden');document.getElementById('$modalId').classList.add('flex');";

  /// Returns JavaScript to close this modal
  static String closeScript(String modalId) =>
      "document.getElementById('$modalId').classList.add('hidden');document.getElementById('$modalId').classList.remove('flex');";
}

/// Helper extension to add modal trigger to any component
extension ModalTrigger on Component {
  /// Wraps this component in a button that opens the specified modal
  Component asModalTrigger(String modalId) {
    return button(
      attributes: {'onclick': DModal.openScript(modalId)},
      [this],
    );
  }
}
