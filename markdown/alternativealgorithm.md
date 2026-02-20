## Alternative Algorithm

This panel runs the lottery using an alternative selection method for comparison purposes. The algorithm works as follows:

1. **Assign ticket numbers.** Every ticket held by every entrant is assigned a unique random number between 1 and the total number of tickets in the pool.

2. **Draw a START number.** A single reference number (START) is drawn at random from the same range.

3. **Order by distance.** All tickets are ranked by how far their number is from START, counting upward. For example, if START is 50 and the total tickets number 100, then ticket 51 is closest (distance 1), ticket 52 is next (distance 2), and so on. Counting wraps around past the maximum back to 1, so ticket 49 would have distance 99.

4. **Select entrants.** Walking up from START, entrants are selected in order. Once an entrant has been selected, any remaining tickets they hold are skipped.

The first 86 entrants selected become the winners; the next 75 become the waitlist.

Because each ticket is assigned an independent random position on the number line (rather than occupying a contiguous block), an entrant with more tickets has proportionally more chances to land close to START — making this method statistically similar to standard weighted sampling.
