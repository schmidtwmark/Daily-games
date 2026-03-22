(function() {
    try {
        const text = document.body.innerText || '';

        if (text.includes('Completed') || text.includes('Finished')) {
            return JSON.stringify({ completed: true, won: true });
        }
    } catch(e) {
        console.error('Bracket City completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false });
})();
