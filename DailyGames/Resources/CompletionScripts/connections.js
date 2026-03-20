(function() {
    try {
        // Check localStorage for game state
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('games-state-connections')) {
                try {
                    const data = JSON.parse(localStorage.getItem(key));
                    const states = data.states || [];
                    for (const state of states) {
                        if (state.data && state.data.puzzleComplete) {
                            return JSON.stringify({
                                completed: true,
                                won: state.data.puzzleWon === true,
                                mistakes: state.data.mistakes || 0
                            });
                        }
                    }
                } catch(e) {}
            }
        }
    } catch(e) {
        console.error('Connections completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false, mistakes: null });
})();
