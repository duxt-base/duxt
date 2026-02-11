import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_signals/duxt_signals.dart';

final _nameField = formField('', validators: [
  required('Name is required'),
]);

final _emailField = formField('', validators: [
  required('Email is required'),
]);

final _messageField = formField('', validators: [
  required('Message is required'),
]);

final _submitted = signal(false);

@client
class DemoPage extends StatefulComponent {
  const DemoPage({super.key});

  @override
  State createState() => _DemoPageState();
}

class _DemoPageState extends SignalState<DemoPage> {
  @override
  Component buildComponent(BuildContext context) {
    return Div(
      className: 'py-12 px-4',
      child: Div(
        className: 'max-w-lg mx-auto',
        children: [
          Div(
            className: 'text-center mb-8',
            children: [
              H1(
                className: 'text-4xl font-bold text-white mb-4',
                child: Text('Form Validation'),
              ),
              P(
                className: 'text-gray-400',
                child: Text('Using formField() with built-in validators'),
              ),
            ],
          ),
          Div(
            className: 'rounded-xl p-6 bg-gray-900 border border-gray-800',
            children: [
              if (_submitted())
                _successMessage()
              else
                _formContent(),
            ],
          ),
        ],
      ),
    );
  }

  Component _successMessage() {
    return Div(
      className: 'text-center py-8',
      children: [
        Div(
          className: 'text-4xl mb-4',
          child: Text('✓'),
        ),
        H2(
          className: 'text-2xl font-bold text-emerald-400 mb-2',
          child: Text('Message Sent!'),
        ),
        P(
          className: 'text-gray-400 mb-6',
          child: Text('Thanks for reaching out.'),
        ),
        Button(
          onClick: () {
            _nameField.reset();
            _emailField.reset();
            _messageField.reset();
            _submitted.set(false);
          },
          className: 'px-4 py-2 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors',
          child: Text('Send Another'),
        ),
      ],
    );
  }

  Component _formContent() {
    return Div(
      className: 'space-y-4',
      children: [
        _field(
          label: 'Name',
          value: _nameField(),
          placeholder: 'Your name',
          onInput: (v) => _nameField.set(v),
          onBlur: () => _nameField.touch(),
          hasError: _nameField.touched && _nameField.hasError,
          errorText: _nameField.error,
        ),
        _field(
          label: 'Email',
          value: _emailField(),
          placeholder: 'your@email.com',
          type: 'email',
          onInput: (v) => _emailField.set(v),
          onBlur: () => _emailField.touch(),
          hasError: _emailField.touched && _emailField.hasError,
          errorText: _emailField.error,
        ),
        Div(
          children: [
            Label(
              className: 'block text-sm font-medium text-gray-300 mb-1',
              child: Text('Message'),
            ),
            Textarea(
              name: 'message',
              placeholder: 'Your message...',
              rows: 4,
              onInput: (v) => _messageField.set(v),
              events: {'blur': (_) => _messageField.touch()},
              className: 'w-full px-3 py-2 bg-gray-800 border ${_messageField.touched && _messageField.hasError ? "border-red-500" : "border-gray-700"} rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
            ),
            if (_messageField.touched && _messageField.hasError)
              Div(
                className: 'mt-1 text-sm text-red-400',
                child: Text(_messageField.error ?? ''),
              ),
          ],
        ),
        Div(
          className: 'flex items-center justify-between pt-2',
          children: [
            Button(
              onClick: () {
                _nameField.touch();
                _emailField.touch();
                _messageField.touch();
                if (_nameField.isValid && _emailField.isValid && _messageField.isValid) {
                  _submitted.set(true);
                }
              },
              className: 'px-6 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors font-medium',
              child: Text('Submit'),
            ),
            Button(
              onClick: () {
                _nameField.reset();
                _emailField.reset();
                _messageField.reset();
              },
              className: 'text-sm text-gray-500 hover:text-gray-300 transition-colors',
              child: Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }

  Component _field({
    required String label,
    required String value,
    required String placeholder,
    String type = 'text',
    required void Function(String) onInput,
    required void Function() onBlur,
    required bool hasError,
    String? errorText,
  }) {
    return Div(
      children: [
        Label(
          className: 'block text-sm font-medium text-gray-300 mb-1',
          child: Text(label),
        ),
        Input(
          type: type,
          value: value,
          placeholder: placeholder,
          onInput: onInput,
          events: {'blur': (_) => onBlur()},
          className: 'w-full px-3 py-2 bg-gray-800 border ${hasError ? "border-red-500" : "border-gray-700"} rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500',
        ),
        if (hasError)
          Div(
            className: 'mt-1 text-sm text-red-400',
            child: Text(errorText ?? ''),
          ),
      ],
    );
  }
}
