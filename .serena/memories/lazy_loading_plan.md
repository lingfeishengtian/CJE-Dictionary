I need to implement a lazy-loading approach for search results that returns keys/references instead of full records immediately. This is a significant architectural change that involves:

1. Creating a new SearchResultKey/Reference type that holds minimal information
2. Modifying DictionaryProtocol to return these references instead of full DatabaseWord objects
3. Implementing a method to fetch the actual record from a key
4. Starting to build a new UI view that works with this lazy-loading approach

Let me focus on implementing this lazy-loading architecture properly.