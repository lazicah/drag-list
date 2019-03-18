import 'package:drag_list/drag_list.dart';
import 'package:flutter/material.dart';

void main() => runApp(CountriesPage());

class CountriesPage extends StatelessWidget {
  final _itemHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragList example',
      home: Scaffold(
        appBar: AppBar(title: Text('Largest countries')),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: DragList<String>.handleless(
            items: _countries,
            itemExtent: _itemHeight,
            builder: (_, item) {
              return Container(
                height: _itemHeight,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: Text(item)),
                ),
              );
            },
          ),
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
