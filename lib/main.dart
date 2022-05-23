import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
          create: (_) => PersonBloc(),
          child:const PageView()
        );
  }
}

class PageView extends StatelessWidget {
  const PageView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: const Text("Bloc"),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                  onPressed: () {
                    context.read<PersonBloc>().add(
                        const LoadPersonsAction(url: PersonUrl.person1));
                  },
                  child: const Text("Json #1")),
              TextButton(
                  onPressed: () {
                    context.read<PersonBloc>().add(
                        const LoadPersonsAction(url: PersonUrl.person2));
                  },
                  child: const Text("Json #2"))
            ],
          ),
          BlocBuilder<PersonBloc, FetchResult?>(
            buildWhen: (previousResult, currentResult) {
              return previousResult?.persons != currentResult?.persons;
            },
            builder: ((context, result) {
              final persons = result?.persons;
              if (persons == null) {
                return const SizedBox();
              }
              return Expanded(
                  child: ListView.builder(
                    itemCount: persons.length,
                    itemBuilder: (context, index) {
                      final person = persons[index]!;
                      return ListTile(
                        title: Text(person.name),
                      );
                    },
                  ));
            }),
          )
        ],
      ),
    );
  }
}


@immutable
abstract class LoadAction {
  const LoadAction();
}

class LoadPersonsAction implements LoadAction {
  final PersonUrl url;

  const LoadPersonsAction({required this.url});
}

@immutable
class Person {
  final String name;
  final int age;

  const Person({required this.name, required this.age});

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;
}

enum PersonUrl { person1, person2 }

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.person1:
        return "http://192.168.1.111:8081/api/person1.json";
      case PersonUrl.person2:
        return "http://192.168.1.111:8081/api/person2.json";
    }
  }
}

extension Subscripte<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetreivedFromCache;

  const FetchResult(
      {required this.persons, required this.isRetreivedFromCache});

  @override
  String toString() =>
      'isFetchFromCache = $isRetreivedFromCache, persons = $persons';
}

class PersonBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};

  PersonBloc() : super(null) {
    on<LoadPersonsAction>((event, emit) async {
      final url = event.url;

      if (_cache.containsKey(url)) {
        final cachePerson = _cache[url];
        final result =
            FetchResult(persons: cachePerson!, isRetreivedFromCache: true);
        emit(result);
      } else {
        final persons = await getPersons(url.urlString);
        _cache[url] = persons;
        final result =
            FetchResult(persons: persons, isRetreivedFromCache: false);
        emit(result);
      }
    });
  }
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((response) => response.transform(utf8.decoder).join())
    .then((jsonString) => json.decode(jsonString) as List<dynamic>)
    .then((json) => json.map((map) => Person.fromJson(map)));
