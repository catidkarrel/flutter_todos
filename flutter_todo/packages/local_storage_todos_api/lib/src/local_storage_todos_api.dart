import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todos_api/todos_api.dart';

/// {@template local_storage_todos_api}
/// A Flutter implementation of the TodosApi that uses local storage.
/// {@endtemplate}
class LocalStorageTodosApi extends TodosApi {
  /// {@macro local_storage_todos_api}
  LocalStorageTodosApi({
    required SharedPreferences plugin,
  }) : _plugin = plugin {
    _init();
  }

  final SharedPreferences _plugin;

  late final _todoStreamController = BehaviorSubject<List<Todo>>.seeded(
    const [],
  );

  /// The key used to store the todos in the local storage.
  @visibleForTesting
  static const kTodoCollectionKey = '__todos_collection_key__';

  String? _getValue(String key) => _plugin.getString(key);
  Future<void> _setValue(String key, String value) =>
      _plugin.setString(key, value);

  void _init() {
    final todosJson = _getValue(kTodoCollectionKey);
    if (todosJson != null) {
      final todos =
        List<Map<dynamic, dynamic>>.from(
          json.decode(todosJson) as List,
        )
        .map(
          (jsonMap) => Todo.fromJson(Map<String, dynamic>.from(jsonMap)),
        )
        .toList();
      _todoStreamController.add(todos);
    } else {
      _todoStreamController.add(const []);
    }
  }

  /// {@macro todos_api.getTodos}
  @override
  Stream<List<Todo>> getTodos() => _todoStreamController.stream;

  @override
  Future<void> saveTodo(Todo todo) {
    final todos = [..._todoStreamController.value];
    final todoIndex = todos.indexWhere((t) => t.id == todo.id);
    if (todoIndex >= 0) {
      todos[todoIndex] = todo;
    } else {
      todos.add(todo);
    }

    _todoStreamController.add(todos);
    return _setValue(
      kTodoCollectionKey,
      json.encode(todos),
    );
  }

  @override
  Future<void> deleteTodo(String id) async {
    final todos = [..._todoStreamController.value];
    final todoIndex = todos.indexWhere((t) => t.id == id);
    if (todoIndex == -1) {
      throw TodoNotFoundException();
    } else {
      todos.removeAt(todoIndex);
      _todoStreamController.add(todos);
      return _setValue(
        kTodoCollectionKey,
        json.encode(todos),
      );
    }
  }

  @override
  Future<int> clearCompleted() async {
    final todos = [..._todoStreamController.value];
    final initialLength = todos.length;

    todos.removeWhere((t) => t.isCompleted);
    final completedTodosCount = initialLength - todos.length;
    _todoStreamController.add(todos);
    await _setValue(
      kTodoCollectionKey,
      json.encode(todos),
    );
    return completedTodosCount;
  }

  @override
  Future<int> completeAll({required bool isCompleted}) async {
    final todos = [..._todoStreamController.value];
    final changedTodosAmount = todos
      .where((t) => t.isCompleted != isCompleted)
      .length;
    final newTodos = [
      for (final todo in todos) todo.copyWith(isCompleted: isCompleted)
    ];
    _todoStreamController.add(newTodos);
    await _setValue(kTodoCollectionKey, json.encode(newTodos));
    return changedTodosAmount;
  }

  @override
  Future<void> close() {
    return _todoStreamController.close();
  }
}
