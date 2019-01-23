import 'package:drag_list/drag_list.dart';
import 'package:flutter/material.dart';

void main() => runApp(CountriesPage());

class CountriesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragList example',
      home: Scaffold(
        appBar: AppBar(title: Text('Largest countries')),
        body: DragList<String>(
          items: _countries,
          itemExtent: 64.0,
          handleBuilder: (_) => Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.drag_handle),
              ),
          builder: (_, item, handle) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(item),
                trailing: handle,
              ),
            );
          },
          onItemReorder: (int from, int to) =>
              _countries.insert(to, _countries.removeAt(from)),
        ),
      ),
    );
  }

  final _countries = [
    'Russia',
    'China',
    'United States',
    'Canada',
    'Brazil',
    'Australia',
    'India',
    'Argentina',
    'Kazakhstan',
    'Algeria',
    'DR Congo',
    'Saudi',
    'Mexico',
    'Indonesia',
    'Sudan',
    'Libya',
    'Iran',
    'Mongolia',
    'Peru',
    'Niger',
  ];
}
