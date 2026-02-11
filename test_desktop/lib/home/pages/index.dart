import 'package:jaspr/jaspr.dart' hide Text;
import 'package:duxt_html/duxt_html.dart';
import 'package:duxt_signals/duxt_signals.dart';

final _count = signal(0);
final _doubleCount = computed(() => _count() * 2);

@client
class HomePage extends StatefulComponent {
  const HomePage({super.key});

  @override
  State createState() => _HomePageState();
}

class _HomePageState extends SignalState<HomePage> {
  @override
  Component buildComponent(BuildContext context) {
    return Div(
      className: 'py-20 px-4',
      child: Div(
        className: 'max-w-3xl mx-auto text-center',
        children: [
          Span(
            className: 'inline-block px-4 py-1.5 mb-6 text-sm font-medium text-emerald-400 bg-emerald-500/10 rounded-full',
            child: Text('Client-Side Rendering'),
          ),
          H1(
            className: 'text-5xl font-bold text-white mb-6',
            child: Text('test_desktop'),
          ),
          P(
            className: 'text-xl text-gray-400 mb-12',
            child: Text('Interactive SPA with reactive signals'),
          ),

          // Counter card
          Div(
            className: 'max-w-md mx-auto rounded-xl p-8 bg-gray-900 border border-gray-800',
            children: [
              H2(
                className: 'text-xl font-bold text-white mb-2',
                child: Text('Reactive Counter'),
              ),
              P(
                className: 'text-sm text-gray-400 mb-6',
                child: Text('Using signal() and computed()'),
              ),
              Div(
                className: 'flex items-center justify-center gap-4 mb-4',
                children: [
                  Button(
                    onClick: () => _count.update((v) => v - 1),
                    className: 'w-12 h-12 rounded-full text-xl font-bold bg-red-600 text-white hover:bg-red-700 transition-colors',
                    child: Text('−'),
                  ),
                  Span(
                    className: 'text-5xl font-bold text-white w-20 text-center',
                    child: Text('${_count()}'),
                  ),
                  Button(
                    onClick: () => _count.update((v) => v + 1),
                    className: 'w-12 h-12 rounded-full text-xl font-bold bg-emerald-600 text-white hover:bg-emerald-700 transition-colors',
                    child: Text('+'),
                  ),
                ],
              ),
              Div(
                className: 'text-gray-400 mb-4',
                child: Text('Double: ${_doubleCount()}'),
              ),
              Button(
                onClick: () => _count.set(0),
                className: 'text-sm text-gray-500 hover:text-gray-300 transition-colors',
                child: Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
