(function() {
    try {
        const html = document.body.innerHTML || '';
        const today = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD format

        // Check localStorage for game state
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('games-state-wordleV2')) {
                try {
                    const data = JSON.parse(localStorage.getItem(key));
                    const states = data.states || [];
                    for (const state of states) {
                        if (state.data) {
                            const status = state.data.status;
                            const printDate = state.printDate;
                            const guesses = state.data.currentRowIndex || 0;
                            // Check if this is today's puzzle
                            if (printDate === today || !state.data.isPlayingArchive) {
                                if (status === 'WIN') {
                                    return JSON.stringify({
                                        completed: true,
                                        won: true,
                                        guesses: guesses
                                    });
                                }
                                if (status === 'FAIL') {
                                    return JSON.stringify({
                                        completed: true,
                                        won: false,
                                        guesses: 6
                                    });
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }

        // Fallback: check for Admire Puzzle in HTML (it's a data-testid attribute)
        if (html.includes('Admire Puzzle')) {
            return JSON.stringify({ completed: true, won: true, guesses: null });
        }
    } catch(e) {
        console.error('Wordle completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false, guesses: null });
})();
