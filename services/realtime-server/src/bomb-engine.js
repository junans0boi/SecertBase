/**
 * Bomb Passing Game Engine
 * 
 * Rules:
 * - Timer starts (e.g., 30 seconds)
 * - Player must answer a quiz question correctly
 * - On correct answer, bomb passes to next player
 * - If timer expires, current player loses
 * - Categories: general knowledge, math, word puzzle
 */

export const QUIZ_CATEGORIES = [
  'general',
  'math',
  'word',
  'kpop',
  'movie',
];

const QUIZ_POOL = {
  general: [
    { question: '한국의 수도는?', answer: '서울', alternatives: ['서울', 'seoul'] },
    { question: '지구에서 가장 큰 대륙은?', answer: '아시아', alternatives: ['아시아', 'asia'] },
    { question: '물의 끓는점은 섭씨 몇도?', answer: '100', alternatives: ['100', '100도'] },
  ],
  math: [
    { question: '7 × 8 = ?', answer: '56', alternatives: ['56'] },
    { question: '15 + 27 = ?', answer: '42', alternatives: ['42'] },
    { question: '81 ÷ 9 = ?', answer: '9', alternatives: ['9'] },
  ],
  word: [
    { question: '철수, 영희, 민수, 지연 중 여자는?', answer: '영희', alternatives: ['영희', '지연', '영희,지연', '지연,영희'] },
    { question: 'KOREA를 거꾸로 쓰면?', answer: 'aerok', alternatives: ['aerok', 'AEROK'] },
  ],
};

/**
 * Get random quiz question
 */
export function getRandomQuiz(category = null) {
  const selectedCategory = category || QUIZ_CATEGORIES[Math.floor(Math.random() * QUIZ_CATEGORIES.length)];
  const pool = QUIZ_POOL[selectedCategory] || QUIZ_POOL.general;
  const quiz = pool[Math.floor(Math.random() * pool.length)];
  
  return {
    category: selectedCategory,
    question: quiz.question,
    answer: quiz.answer,
    alternatives: quiz.alternatives,
  };
}

/**
 * Check if answer is correct
 */
export function checkAnswer(answer, alternatives) {
  const normalized = answer.trim().toLowerCase();
  return alternatives.some((alt) => alt.toLowerCase() === normalized);
}

/**
 * Create bomb game state
 */
export function createBombGameState(players, duration = 30) {
  return {
    players,
    currentPlayer: players[0],
    startTime: Date.now(),
    duration: duration * 1000, // Convert to milliseconds
    currentQuiz: getRandomQuiz(),
    passCount: 0,
    loser: null,
  };
}

/**
 * Check if time is up
 */
export function isTimeUp(gameState) {
  return Date.now() - gameState.startTime >= gameState.duration;
}

/**
 * Pass bomb to next player
 */
export function passBomb(gameState) {
  const currentIndex = gameState.players.indexOf(gameState.currentPlayer);
  const nextIndex = (currentIndex + 1) % gameState.players.length;
  gameState.currentPlayer = gameState.players[nextIndex];
  gameState.currentQuiz = getRandomQuiz();
  gameState.passCount++;
}
