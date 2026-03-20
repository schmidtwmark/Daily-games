(function() {
    try {
        const text = document.body.innerText || '';

        if (text.includes('Completed')) {
            return JSON.stringify({ completed: true, won: true });
        }
    } catch(e) {
        console.error('Bracket City completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false });
})();
