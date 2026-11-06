import assert from 'node:assert/strict';
import test from 'node:test';
import { LOBBY_OPTIONS, defaultLobbyOptions, isValidLobbyOption, normalizeLobbyOptions } from '../src/lobby-options.js';

test('each option game has defaults that are among its allowed values', () => {
  for (const [gameType, spec] of Object.entries(LOBBY_OPTIONS)) {
    for (const [key, def] of Object.entries(spec)) {
      assert.ok(def.values.includes(def.default), `${gameType}.${key}`);
    }
  }
  assert.deepEqual(defaultLobbyOptions('penalty'), { cells: 3 });
  assert.deepEqual(defaultLobbyOptions('pirate'), { holes: 8 });
  assert.deepEqual(defaultLobbyOptions('uno'), { mode: 'go_wild' });
  assert.deepEqual(defaultLobbyOptions('blackjack'), {});
});

test('only listed values pass validation, with no type coercion', () => {
  assert.equal(isValidLobbyOption('penalty', 'cells', 6), true);
  assert.equal(isValidLobbyOption('penalty', 'cells', 9), false);
  assert.equal(isValidLobbyOption('penalty', 'cells', '6'), false);
  assert.equal(isValidLobbyOption('pirate', 'holes', 7), false);
  assert.equal(isValidLobbyOption('uno', 'mode', 'classic'), true);
  assert.equal(isValidLobbyOption('uno', 'cells', 3), false);
  assert.equal(isValidLobbyOption('blackjack', 'cells', 3), false);
  assert.equal(isValidLobbyOption('penalty', '__proto__', 3), false, 'prototype keys are not options');
  assert.equal(isValidLobbyOption('penalty', 'constructor', 3), false);
});

test('normalizing keeps valid values, drops unknown keys and fills defaults', () => {
  assert.deepEqual(normalizeLobbyOptions('penalty', { cells: 6, extra: 1 }), { cells: 6 });
  assert.deepEqual(normalizeLobbyOptions('penalty', { cells: 9 }), { cells: 3 });
  assert.deepEqual(normalizeLobbyOptions('pirate', null), { holes: 8 });
  assert.deepEqual(normalizeLobbyOptions('blackjack', { cells: 3 }), {});
});

test('telepathy offers 10|5|15 questions and a spicy switch that is off by default', () => {
  assert.deepEqual(defaultLobbyOptions('telepathy'), { rounds: 10, spicy: 'off' });
  assert.equal(isValidLobbyOption('telepathy', 'rounds', 15), true);
  assert.equal(isValidLobbyOption('telepathy', 'rounds', 20), false);
  assert.equal(isValidLobbyOption('telepathy', 'spicy', 'on'), true);
  assert.equal(isValidLobbyOption('telepathy', 'spicy', true), false);
  assert.deepEqual(normalizeLobbyOptions('telepathy', { rounds: 5, spicy: 'on' }), { rounds: 5, spicy: 'on' });
  assert.deepEqual(normalizeLobbyOptions('telepathy', { rounds: '5' }), { rounds: 10, spicy: 'off' });
});
