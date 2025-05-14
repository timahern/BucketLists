describe('My Bucket List App', () => {
  

  beforeEach(() => {
    cy.visit('http://127.0.0.1:8080');
    cy.wait(20000);
    cy.get('flt-glass-pane', { timeout: 20000 }).should('exist');
    cy.contains('[data-key="hello-again-text"]').should('be.visible');
  });

  it('checks title', () => {
    cy.contains('Hello Again!')
  });
})