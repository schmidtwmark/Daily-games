(function() {
    try {
        const url = window.location.href;
        const text = document.body.innerText || '';
        const today = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD format

        // Check streak data in localStorage
        const bootstrap = localStorage.getItem('puzzmoBootstrapData');
        if (bootstrap) {
            const data = JSON.parse(bootstrap);
            const streak = data.userState?.streak || {};

            // Determine which game based on URL
            let gameKey = null;
            if (url.includes('/ribbit')) gameKey = 'ribbit';
            else if (url.includes('/circuits')) gameKey = 'circuits';
            else if (url.includes('/really-bad-chess')) gameKey = 'really-bad-chess';
            else if (url.includes('/crossword/mini')) gameKey = 'crossword:mini-xword';
            else if (url.includes('/crossword/big')) gameKey = 'crossword:big-xword';
            else if (url.includes('/crossword')) gameKey = 'crossword';

            if (gameKey && streak[gameKey]) {
                const gameStreak = streak[gameKey];
                const lastUpdated = gameStreak.lastUpdated;
                const isCompleted = lastUpdated === today;

                return JSON.stringify({
                    completed: isCompleted,
                    won: isCompleted,
                    streak: gameStreak.current || 0,
                    maxStreak: gameStreak.max || 0,
                    totalPlayed: gameStreak.total || 0
                });
            }
        }

        // Fallback: check for "Puzzle Complete" text
        if (text.includes('Puzzle Complete')) {
            return JSON.stringify({
                completed: true,
                won: true,
                streak: null,
                maxStreak: null,
                totalPlayed: null
            });
        }
    } catch(e) {
        console.error('Puzzmo completion detection error:', e);
    }
    return JSON.stringify({
        completed: false,
        won: false,
        streak: null,
        maxStreak: null,
        totalPlayed: null
    });
})();
