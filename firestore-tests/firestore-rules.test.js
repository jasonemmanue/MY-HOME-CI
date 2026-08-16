// ══════════════════════════════════════════════════════════════════════════
//  Tests des regles de securite Firestore — My Home CI
//
//  Une regle non testee est une fuite de donnees : elle compile, elle se
//  deploie, et personne ne sait ce qu'elle autorise reellement. Ce fichier
//  verifie les promesses que le produit fait a ses utilisateurs.
//
//  Tout s'execute contre l'emulateur, sur un projet « demo- » qui ne peut par
//  construction joindre aucun service Google reel.
//
//    npm test        (depuis firestore-tests/)
// ══════════════════════════════════════════════════════════════════════════

import { before, after, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc,
  collection, query, where, orderBy, getDocs, serverTimestamp,
} from 'firebase/firestore';

const ICI = dirname(fileURLToPath(import.meta.url));

const ALICE = 'alice';   // proprietaire, auteur des annonces
const BOB = 'bob';       // locataire, participant de la conversation
const MALLORY = 'mallory'; // tiers sans lien avec quoi que ce soit
const ADMIN = 'patronne';

let env;

/** Firestore d'un visiteur non authentifie. */
const visiteur = () => env.unauthenticatedContext().firestore();
/** Firestore d'un utilisateur connecte sans privilege. */
const connecte = (uid) => env.authenticatedContext(uid).firestore();
/** Firestore d'un administrateur — le role vient du custom claim, pas d'un champ. */
const admin = () => env.authenticatedContext(ADMIN, { admin: true }).firestore();

function profil(nom, role) {
  return {
    name: nom,
    photoUrl: null,
    role,
    isVerified: false,
    isPro: false,
    proUntil: null,
    isSuspended: false,
    suspendedUntil: null,
    createdAt: new Date(),
    lastSeenAt: new Date(),
    propertyCount: 0,
  };
}

function annonce(statut, proprietaire = ALICE) {
  return {
    ownerId: proprietaire,
    title: 'Studio meuble a Cocody',
    description: 'Un logement correct, decrit avec suffisamment de details.',
    price: 150000,
    status: statut,
    type: 'studio',
    quarter: 'Cocody',
    city: 'Abidjan',
    geohash: 's1234567',
    searchKeywords: ['studio', 'cocody'],
    views: 10,
    favoritesCount: 2,
    boostedUntil: null,
    createdAt: new Date(),
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-my-home-ci',
    firestore: {
      rules: readFileSync(join(ICI, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Jeu de donnees pose en contournant les regles : on teste la lecture et
  // l'ecriture des regles, pas leur capacite a s'amorcer elles-memes.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, 'users', ALICE), profil('Alice', 'owner'));
    await setDoc(doc(db, 'users', BOB), profil('Bob', 'tenant'));
    await setDoc(doc(db, 'users', MALLORY), profil('Mallory', 'tenant'));
    await setDoc(doc(db, 'users', ALICE, 'private', 'contact'), {
      email: 'alice@example.ci',
      phone: '+2250700000000',
    });

    await setDoc(doc(db, 'properties', 'p_active'), annonce('active'));
    await setDoc(doc(db, 'properties', 'p_draft'), annonce('draft'));
    await setDoc(doc(db, 'properties', 'p_pending'), annonce('pending'));
    await setDoc(doc(db, 'properties', 'p_rejected'), annonce('rejected'));

    await setDoc(doc(db, 'conversations', 'c1'), {
      participants: [ALICE, BOB],
      propertyId: 'p_active',
      propertyTitle: 'Studio meuble a Cocody',
      lastMessage: 'Bonjour',
      lastMessageTime: new Date(),
    });
    await setDoc(doc(db, 'conversations', 'c1', 'messages', 'm1'), {
      senderId: BOB,
      text: 'Le logement est-il toujours disponible ?',
      type: 'text',
      isRead: false,
      createdAt: new Date(),
    });

    await setDoc(doc(db, 'transactions', 't1'), {
      uid: ALICE, product: 'pro', amount: 15000, status: 'success',
    });
    await setDoc(doc(db, 'webPayments', 'jeton1'), {
      uid: ALICE, product: 'pro', status: 'pending',
    });
    await setDoc(doc(db, 'quarters', 'cocody'), {
      name: 'Cocody', isPopular: true, sortOrder: 0,
    });
    await setDoc(doc(db, 'adminSettings', 'general'), { maintenance: false });
    await setDoc(doc(db, 'reports', 'r1'), {
      reason: 'Annonce frauduleuse', status: 'pending', targetId: 'p_active',
    });
    await setDoc(doc(db, 'verificationRequests', ALICE), { status: 'pending' });
    await setDoc(doc(db, 'users', BOB, 'notifications', 'n1'), {
      title: 'Nouveau message', isRead: false,
    });
  });
});

after(async () => {
  await env?.cleanup();
});

// ── La promesse : consulter sans compte ───────────────────────────────────
describe('Consultation sans compte', () => {
  it('un visiteur lit une annonce publiee', async () => {
    await assertSucceeds(getDoc(doc(visiteur(), 'properties', 'p_active')));
  });

  it('un visiteur liste les annonces publiees', async () => {
    await assertSucceeds(getDocs(query(
      collection(visiteur(), 'properties'),
      where('status', '==', 'active'),
      orderBy('createdAt', 'desc'),
    )));
  });

  it('un visiteur lit les fiches quartier', async () => {
    await assertSucceeds(getDoc(doc(visiteur(), 'quarters', 'cocody')));
  });

  it('un visiteur lit un profil public', async () => {
    await assertSucceeds(getDoc(doc(visiteur(), 'users', ALICE)));
  });
});

// ── Les annonces non publiees ne fuient pas ───────────────────────────────
describe('Annonces non publiees', () => {
  for (const statut of ['draft', 'pending', 'rejected']) {
    it(`un tiers ne lit pas une annonce « ${statut} »`, async () => {
      await assertFails(getDoc(doc(connecte(MALLORY), 'properties', `p_${statut}`)));
    });
  }

  it('le proprietaire lit ses propres brouillons', async () => {
    await assertSucceeds(getDoc(doc(connecte(ALICE), 'properties', 'p_draft')));
  });

  it("l'administrateur lit une annonce en moderation", async () => {
    await assertSucceeds(getDoc(doc(admin(), 'properties', 'p_pending')));
  });

  it('une liste sans filtre de statut est refusee au visiteur', async () => {
    // Firestore refuse toute requete dont il ne peut pas prouver que chaque
    // document renvoye serait lisible : sans `where status == active`, la
    // liste pourrait contenir des brouillons.
    await assertFails(getDocs(collection(visiteur(), 'properties')));
  });
});

// ── Ecriture sur les annonces ─────────────────────────────────────────────
describe('Ecriture sur les annonces', () => {
  it("un tiers ne modifie pas l'annonce d'autrui", async () => {
    await assertFails(updateDoc(doc(connecte(MALLORY), 'properties', 'p_active'), {
      title: 'Annonce detournee', price: 1,
    }));
  });

  it("un tiers ne supprime pas l'annonce d'autrui", async () => {
    await assertFails(deleteDoc(doc(connecte(MALLORY), 'properties', 'p_active')));
  });

  it('un proprietaire ne publie pas son annonce sans moderation', async () => {
    await assertFails(updateDoc(doc(connecte(ALICE), 'properties', 'p_draft'), {
      status: 'active',
    }));
  });

  it("un proprietaire ne s'offre pas un boost", async () => {
    await assertFails(updateDoc(doc(connecte(ALICE), 'properties', 'p_draft'), {
      boostedUntil: new Date(Date.now() + 7 * 86400_000),
    }));
  });

  it('un proprietaire ne gonfle pas son compteur de vues', async () => {
    await assertFails(updateDoc(doc(connecte(ALICE), 'properties', 'p_draft'), {
      title: 'Studio meuble a Cocody, revu', views: 99999,
    }));
  });

  it("une annonce ne peut pas naitre au nom d'un autre", async () => {
    await assertFails(setDoc(doc(connecte(MALLORY), 'properties', 'p_usurpee'),
      annonce('draft', ALICE)));
  });

  it('une annonce ne peut pas naitre publiee', async () => {
    await assertFails(setDoc(doc(connecte(ALICE), 'properties', 'p_neuve'),
      annonce('active')));
  });

  it('un prix nul ou negatif est refuse', async () => {
    await assertFails(setDoc(doc(connecte(ALICE), 'properties', 'p_gratuite'),
      { ...annonce('draft'), price: 0 }));
  });

  it('un brouillon valide est accepte', async () => {
    await assertSucceeds(setDoc(doc(connecte(ALICE), 'properties', 'p_ok'),
      annonce('draft')));
  });

  it("l'administrateur publie une annonce en attente", async () => {
    await assertSucceeds(updateDoc(doc(admin(), 'properties', 'p_pending'), {
      status: 'active',
    }));
  });
});

// ── Compteurs publics ─────────────────────────────────────────────────────
// Vues et favoris sont les deux seuls champs qu'un inconnu peut toucher. La
// tentation est de se contenter de restreindre les champs modifiables ; il
// faut aussi contraindre la valeur, sinon « qui peut ecrire un compteur » veut
// dire « qui peut ecrire n'importe quel nombre dedans ».
describe('Compteurs publics', () => {
  // withSecurityRulesDisabled ne renvoie pas la valeur de son callback : on
  // passe par une variable de fermeture pour recuperer l'etat courant.
  async function compteur(champ) {
    let valeur;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), 'properties', 'p_active'));
      valeur = snap.data()[champ];
    });
    return valeur;
  }

  it('un visiteur incremente les vues de un', async () => {
    const avant = await compteur('views');
    await assertSucceeds(updateDoc(doc(visiteur(), 'properties', 'p_active'), {
      views: avant + 1,
    }));
  });

  it("un visiteur ne s'attribue pas un million de vues", async () => {
    await assertFails(updateDoc(doc(visiteur(), 'properties', 'p_active'), {
      views: 1_000_000,
    }));
  });

  it("un visiteur ne remet pas a zero les vues d'un concurrent", async () => {
    await assertFails(updateDoc(doc(visiteur(), 'properties', 'p_active'), {
      views: 0,
    }));
  });

  it('une mise en favori et un retrait passent', async () => {
    await assertSucceeds(updateDoc(doc(connecte(BOB), 'properties', 'p_active'), {
      favoritesCount: (await compteur('favoritesCount')) + 1,
    }));
    await assertSucceeds(updateDoc(doc(connecte(BOB), 'properties', 'p_active'), {
      favoritesCount: (await compteur('favoritesCount')) - 1,
    }));
  });

  it('le compteur de favoris ne passe pas sous zero', async () => {
    await assertFails(updateDoc(doc(connecte(BOB), 'properties', 'p_active'), {
      favoritesCount: -1,
    }));
  });

  it('les deux compteurs ne bougent pas dans la meme ecriture', async () => {
    // Chaque cas de la regle n'autorise qu'un champ : l'application appelle
    // toujours les deux increments separement.
    await assertFails(updateDoc(doc(visiteur(), 'properties', 'p_active'), {
      views: 999, favoritesCount: 999,
    }));
  });
});

// ── Escalade de privileges ────────────────────────────────────────────────
describe('Escalade de privileges', () => {
  for (const champ of ['role', 'isVerified', 'isPro', 'isSuspended', 'propertyCount']) {
    it(`un utilisateur ne s'attribue pas « ${champ} »`, async () => {
      const valeur = champ === 'role' ? 'admin'
        : champ === 'propertyCount' ? 999
        : true;
      await assertFails(updateDoc(doc(connecte(BOB), 'users', BOB), { [champ]: valeur }));
    });
  }

  it('un utilisateur modifie son nom', async () => {
    await assertSucceeds(updateDoc(doc(connecte(BOB), 'users', BOB), { name: 'Bob K.' }));
  });

  it("un utilisateur ne modifie pas le profil d'un autre", async () => {
    await assertFails(updateDoc(doc(connecte(MALLORY), 'users', ALICE), { name: 'Pirate' }));
  });

  it('un compte ne peut pas naitre administrateur', async () => {
    await assertFails(setDoc(doc(connecte('nouveau'), 'users', 'nouveau'),
      { ...profil('Nouveau', 'admin') }));
  });

  it('un compte ne peut pas naitre verifie', async () => {
    await assertFails(setDoc(doc(connecte('nouveau2'), 'users', 'nouveau2'),
      { ...profil('Nouveau', 'owner'), isVerified: true }));
  });

  it('une inscription normale est acceptee', async () => {
    await assertSucceeds(setDoc(doc(connecte('nouveau3'), 'users', 'nouveau3'),
      profil('Nouveau', 'tenant')));
  });

  it('aucun compte ne se supprime directement — la Cloud Function fait le menage', async () => {
    await assertFails(deleteDoc(doc(connecte(BOB), 'users', BOB)));
  });
});

// ── Coordonnees privees ───────────────────────────────────────────────────
describe('Coordonnees privees', () => {
  it("le telephone d'un utilisateur n'est pas lisible par un tiers", async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'users', ALICE, 'private', 'contact')));
  });

  it("il n'est pas lisible par un visiteur non plus", async () => {
    await assertFails(getDoc(doc(visiteur(), 'users', ALICE, 'private', 'contact')));
  });

  it('le titulaire lit ses propres coordonnees', async () => {
    await assertSucceeds(getDoc(doc(connecte(ALICE), 'users', ALICE, 'private', 'contact')));
  });
});

// ── Conversations ─────────────────────────────────────────────────────────
describe('Conversations', () => {
  it("un tiers ne lit pas une conversation dont il n'est pas participant", async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'conversations', 'c1')));
  });

  it("un tiers ne lit pas les messages non plus", async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'conversations', 'c1', 'messages', 'm1')));
  });

  it('un participant lit la conversation et ses messages', async () => {
    await assertSucceeds(getDoc(doc(connecte(ALICE), 'conversations', 'c1')));
    await assertSucceeds(getDoc(doc(connecte(ALICE), 'conversations', 'c1', 'messages', 'm1')));
  });

  it("un tiers n'ecrit pas dans une conversation", async () => {
    await assertFails(addDoc(collection(connecte(MALLORY), 'conversations', 'c1', 'messages'), {
      senderId: MALLORY, text: 'Injection', type: 'text', createdAt: new Date(),
    }));
  });

  it("un participant n'ecrit pas un message au nom d'un autre", async () => {
    await assertFails(addDoc(collection(connecte(ALICE), 'conversations', 'c1', 'messages'), {
      senderId: BOB, text: 'Faux message', type: 'text', createdAt: new Date(),
    }));
  });

  it('un participant envoie un message signe de son nom', async () => {
    await assertSucceeds(addDoc(collection(connecte(ALICE), 'conversations', 'c1', 'messages'), {
      senderId: ALICE, text: 'Oui, disponible.', type: 'text', createdAt: new Date(),
    }));
  });

  it("l'historique n'est pas reecrit — seul l'accuse de lecture bouge", async () => {
    await assertFails(updateDoc(doc(connecte(ALICE), 'conversations', 'c1', 'messages', 'm1'), {
      text: 'Message reecrit',
    }));
    await assertSucceeds(updateDoc(doc(connecte(ALICE), 'conversations', 'c1', 'messages', 'm1'), {
      isRead: true, readAt: new Date(),
    }));
  });

  it('une conversation ne se cree pas sans son auteur dedans', async () => {
    await assertFails(setDoc(doc(connecte(MALLORY), 'conversations', 'c_faux'), {
      participants: [ALICE, BOB], propertyId: 'p_active',
    }));
  });
});

// ── Argent ────────────────────────────────────────────────────────────────
describe('Argent', () => {
  it('un tiers ne lit pas la transaction de quelqu un d autre', async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'transactions', 't1')));
  });

  it('le payeur lit sa transaction', async () => {
    await assertSucceeds(getDoc(doc(connecte(ALICE), 'transactions', 't1')));
  });

  it("personne n'ecrit une transaction depuis le client", async () => {
    await assertFails(setDoc(doc(connecte(ALICE), 'transactions', 't_faux'), {
      uid: ALICE, product: 'pro', amount: 1, status: 'success',
    }));
    await assertFails(updateDoc(doc(admin(), 'transactions', 't1'), { status: 'refunded' }));
  });

  it('les paiements web restent invisibles, meme a l administrateur', async () => {
    await assertFails(getDoc(doc(admin(), 'webPayments', 'jeton1')));
    await assertFails(getDoc(doc(connecte(ALICE), 'webPayments', 'jeton1')));
  });
});

// ── Moderation et referentiels ────────────────────────────────────────────
describe('Moderation et referentiels', () => {
  it('un visiteur signale une annonce', async () => {
    await assertSucceeds(addDoc(collection(visiteur(), 'reports'), {
      reason: 'Annonce mensongere', status: 'pending', targetId: 'p_active',
    }));
  });

  it('un signalement ne peut pas naitre deja traite', async () => {
    await assertFails(addDoc(collection(visiteur(), 'reports'), {
      reason: 'Peu importe', status: 'resolved', targetId: 'p_active',
    }));
  });

  it('les signalements ne sont lisibles que par l administrateur', async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'reports', 'r1')));
    await assertSucceeds(getDoc(doc(admin(), 'reports', 'r1')));
  });

  it("une demande de verification n'est pas lisible par un tiers", async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'verificationRequests', ALICE)));
    await assertSucceeds(getDoc(doc(connecte(ALICE), 'verificationRequests', ALICE)));
  });

  it("un demandeur ne tranche pas sa propre verification", async () => {
    await assertFails(updateDoc(doc(connecte(ALICE), 'verificationRequests', ALICE), {
      status: 'approved',
    }));
    await assertSucceeds(updateDoc(doc(admin(), 'verificationRequests', ALICE), {
      status: 'approved',
    }));
  });

  it('les quartiers et reglages ne s ecrivent que par l administrateur', async () => {
    await assertFails(setDoc(doc(connecte(MALLORY), 'quarters', 'faux'), { name: 'Faux' }));
    await assertFails(updateDoc(doc(connecte(MALLORY), 'adminSettings', 'general'), {
      maintenance: true,
    }));
    await assertSucceeds(updateDoc(doc(admin(), 'adminSettings', 'general'), {
      maintenance: true,
    }));
  });
});

// ── Notifications ─────────────────────────────────────────────────────────
describe('Notifications', () => {
  it("un tiers ne lit pas les notifications d'autrui", async () => {
    await assertFails(getDoc(doc(connecte(MALLORY), 'users', BOB, 'notifications', 'n1')));
  });

  it('le destinataire marque sa notification comme lue', async () => {
    await assertSucceeds(updateDoc(doc(connecte(BOB), 'users', BOB, 'notifications', 'n1'), {
      isRead: true, readAt: new Date(),
    }));
  });

  it('le destinataire ne reecrit pas le contenu de la notification', async () => {
    await assertFails(updateDoc(doc(connecte(BOB), 'users', BOB, 'notifications', 'n1'), {
      title: 'Titre invente',
    }));
  });

  it('un client ne fabrique pas de notification', async () => {
    await assertFails(setDoc(doc(connecte(BOB), 'users', BOB, 'notifications', 'n_faux'), {
      title: 'Fausse alerte', isRead: false,
    }));
  });
});

// ── Collections non declarees ─────────────────────────────────────────────
describe('Collections non declarees', () => {
  it('une collection inconnue est fermee, meme a l administrateur', async () => {
    await assertFails(setDoc(doc(admin(), 'collectionInventee', 'x'), { a: 1 }));
    await assertFails(getDoc(doc(connecte(ALICE), 'collectionInventee', 'x')));
  });
});
