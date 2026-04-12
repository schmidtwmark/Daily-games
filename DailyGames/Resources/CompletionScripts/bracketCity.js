(function() {
    try {
        var text = document.body.innerText || '';

        if (text.includes('Completed') || text.includes('Finished')) {
            var result = { completed: true, won: true };

            // Extract error count - look for patterns like "0 errors", "1 error", "2 errors"
            var errorMatch = text.match(/(\d+)\s*error/i);
            if (errorMatch) {
                result.errors = parseInt(errorMatch[1], 10);
            }

            // Extract rating - look for common rating patterns
            // Bracket City typically shows ratings like "Perfect", "Great", "Good", etc.
            var ratingPatterns = ['Perfect', 'Excellent', 'Great', 'Good', 'OK', 'Fair'];
            for (var i = 0; i < ratingPatterns.length; i++) {
                // Match the rating word, ensuring it appears in a results context
                var ratingRegex = new RegExp('\\b(' + ratingPatterns[i] + ')\\b', 'i');
                var ratingMatch = text.match(ratingRegex);
                if (ratingMatch) {
                    result.rating = ratingMatch[1];
                    break;
                }
            }

            // Also check for star-based or score-based ratings
            var starMatch = text.match(/(\d+)\s*(?:\/\s*\d+)?\s*star/i);
            if (starMatch && !result.rating) {
                result.rating = starMatch[0].trim();
            }

            return JSON.stringify(result);
        }
    } catch(e) {
        console.error('Bracket City completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false });
})();
