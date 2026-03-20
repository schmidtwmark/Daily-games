(function() {
    try {
        const text = document.body.innerText || '';

        // Check for "Share results" in body text
        if (text.includes('Share results')) {
            return JSON.stringify({ completed: true, won: true });
        }
    } catch(e) {
        console.error('Raddle completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false });
})();
