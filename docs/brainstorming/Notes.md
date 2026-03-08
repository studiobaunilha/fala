A gente vai planejar algumas melhorias aqui.

Uma coisa para a gente planejar depois que a gente entregar essa V1, começar a planejar para a nossa V2 da aplicação, que seria a gravação de reuniões. Eu preciso ter como consumir o áudio do sistema também. Com isso, eu faço uma transcrição com timestamp do meu microfone e uma transcrição com timestamp do microfone do sistema, e na hora da geração do arquivo eu vou encadeando baseado nos horários, né? E até nas prévias eu tenho que fazer de uma maneira inteligente, a gente pode consultar algum exemplo na internet e entender como é feito, mas para fazer transcrição de reuniões, seria bem útil também essa ferramenta ter essa funcionalidade. E por ser uma aplicação de Mac, a gente poderia bolar uma maneira inteligente de mostrar no Notch (tipo aquele app: Notch Nook).


---

Melhorias/ correções:

No esquema de substituição de texto, um pós-processamento ali, ele deveria ser case insensitive, né? Ou seja, ele encontrou, ele deveria substituir, independente se eu escrever aqui maiúscula, minúscula, tanto faz, ele já é desse jeito?

Sobre aquela parte de acurácia versus velocidade, aquilo ali serve somente para a parte de transcrição de arquivos, correto? Eu acho que isso deveria estar claro ali. Que muitas dessas coisas, na verdade, pelo que eu estou vendo aqui, muitas das coisas que estão aqui no avançado, elas são, na verdade, relacionadas à transcrição de arquivo. Acho que isso deveria ficar claro. Pode gerar uma confusão e a gente achar que está mexendo num parâmetro que serviria também para transcrição de áudio do microfone.

O reconhecimento de múltiplos locutores (diarization) não parece estar funcionando. Eu não sei se é por causa do motor que eu estou usando, ou se isso ocorre como um pós-processamento, pré-processamento, mas num teste que eu fiz aqui não está funcionando.

Se eu selecionar o motor Parakeet eu não precisaria ter nenhum modelo whisper baixado. Hoje eu estou obrigando o usuário a fazer isso. Eu poderia simplesmente deixar nenhum selecionado e excluir todos os modelos, né?

Se o idioma da aplicação estiver selecionado para inglês, a gente deveria tirar do menu a opção traduzir para inglês. Seria redundante, né?

Sobre o pós-processamento, a gente criou um "system prompt" que ele serve para qualquer um dos modos, né? Independente do pós-processamento que está selecionado ali. Eu fiquei pensando que isso está hard-coded no sistema. E a gente deveria deixar isso para o usuário poder modificar, sabe? Que é o prompt de sistema, digamos assim, né? Que dá a atribuição para IA qual que é o objetivo dela, o que ela deve fazer e tudo mais. Eu não vejo por que a gente travar e esconder isso do usuário, sabe?


---

Muitas das coisas que às vezes parecem parar de funcionar quando mexemos em algo, eu gostaria que a gente desse uma olhada melhor, porque deveria ter testes automatizados, né, cara, para garantir que isso não vai acontecer, regressão, end to end, sabe? Pra eu não ter que ficar testando cada vez que a gente faz uma modificação, garantir essas coisas através de testes, né?


----

Sobre as atualizações, eu não acho que elas deveriam estar com uma opção no menu. Eu acredito que elas deveriam estar dentro dos ajustes, lá uma opção de atualizações, onde você marca inclusive atualizações automáticas, verificar se tem atualizações em tempo real e mostra a versão e tudo como geralmente se usa nesse tipo de aplicação.

Ainda dentro da questão dos prompt, eu quero que você me explique como está funcionando. Porque, na verdade, o prompt é formado por mais de uma coisa, né? Vou dar um exemplo: o prompt de desenvolvimento. Ele é formado por um prompt geral de sistema que a gente configura num outro lugar, a lista da stack que a pessoa utiliza para desenvolver e o prompt em si de desenvolvimento. Como que isso é usado dentro da aplicação hoje? Como que é montado esse prompt final para poder fazer o pós-processamento na transcrição?


----

- Na questão de seleção de modelos MLX, tem como varrer os modelos disponíveis no HF do mlx-community? Se não der, pelo menos inclua o novo modelo mlx-community/Qwen3.5-4B-MLX-4bit.

- Na troca de motor ou na troca de modelo, se eu fechar a aplicação, abrir de novo, sei lá, qualquer coisa que ainda não tenha baixado um modelo para usar, tem que avisar: você precisa baixar um modelo para poder continuar. Se não tiver um modelo baixado, ele não deveria nem permitir tentar fazer a transcrição enquanto não tiver uma configuração válida.

- Deveria abrir um pop-up ou algum tipo de destaque ali pedindo para reiniciar, sempre que for alterado um parâmetro que pede para reiniciar o aplicativo. Aí você pode cancelar, volta para o estado para a seleção anterior ou você pode confirmar e reiniciar o aplicativo.

- Tem alguma forma de carregar tudo que precisa na hora que seleciona, faz download ou inicializa a aplicação, rodando em segundo plano, sabe? Para ficar tudo pronto, tudo pré-carregado para, na hora que a pessoa for efetivamente usar a transcrição ela não tenha que esperar. O que está acontecendo é que muitas vezes carrega no primeiro uso da transcrição e isso gera uma demora muito incômoda.

- Sobre a validação de licença, eu não sei se já acontece desse jeito, mas seria interessante se quando chegasse a seus prazos ele ficasse fazendo sozinho em segundo plano. Não precisasse a pessoa clicar pra fazer a validação, sabe? Pelo menos a tentativa. Aí ele faz algumas tentativas. Se depois do tempo de vencimento, fazendo as tentativas ainda assim não conseguiu, aí bloqueia o que precisar do trial e tudo mais, né? Acho que já é esperado dessa forma, né? Mas a ideia é essa. Hoje eu tenho a impressão que a pessoa tem que ir lá manualmente e clicar para validar. Eu acho que, cara, desde o começo, primeira vez que abriu a aplicação, ele já teria que tentar validar online em segundo plano e dar início ao trial... não conseguindo, ele pede pra validar manual.

- Sobre questão de usabilidade e interface também, eu não gosto muito desse negócio de às vezes a gente tá com um motor ou um modelo selecionado e a gente fica com um aviso de que não dá pra usar as coisas. Eu queria que a gente planejasse algo diferente disso. Não sei se esconder os recursos, mas se está eles em algum lugar, sabe? Por exemplo, lá na parte da ajuda ou algo assim. Mas, por exemplo, o menu que abre ali a partir do ícone na bandeja, que ele fica com os destaques assim. Parece que tá com um problema que você tem que resolver, sabe? Que nem, por exemplo, habilitar os acessos aí, tudo bem, né? De privacidade e segurança. Porque você vai lá e clica e resolve algo. Agora, se não está disponível por causa do modelo, tal, não sei se a abordagem melhor seria talvez ocultada ali, mas aí deixar claro em algum lugar, lá na seleção de modelos, ou na ajuda, ou alguma coisa assim, mostrar que tem essas possibilidades, tem mais recursos e depende do modelo que você seleciona, sabe?

- Eu acredito que a gente precisa de um configurador, um setup inicial, um onboarding, que abre uma janelinha só de onboarding separada e te ajuda a configurar tudo e fica ali até você configurar o básico. Porque é muito ruim. A cada momento você vai clicar em alguma coisa, fica pedindo aos poucos as coisas, sabe? Eu acho que deveria ter essa telinha separada de onboarding que te garante tudo logo no começo, se habilita todas as permissões, ele vai dando check em cada uma das coisas, um checklist, sabe? Algo nesse sentido. Obviamente seguindo os padrões de interface, UIUX, como se fosse um aplicativo nativo da Apple. Então tem sim que pesquisar lá nos guias da Apple como fazer, que aparência dá, como deixar tudo muito bonitinho e muito bem feito, tá?

---------------

- Como a gente já está suportando modelos locais aqui através do MLX, a gente poderia futuramente numa próxima versão pensar em disponibilizar uma API ou alguma coisa que a pessoa possa usar do jeito que ela bem quiser, né? Mas isso no futuro não é prioridade agora.

----------------
- Quando a aplicação tá num estado parado de espera ali, mas a princípio tá tudo carregado, tá tudo certinho, ele tá mostrando o ícone com uma setinha em sentido anti-horário. Eu não entendi esse ícone, parece um ícone de refresh, de atualizar. Não faz nem sentido o ícone. E eu acho que você tava tentando usar o ícone de download ali. E quando eu coloco o mouse em cima, ele diz que está carregando o modelo Parakeet. Mas não é verdade, porque eu estou usando o normal. E não está batendo com a realidade.


- O Whisper tá demorando muito na primeira transcrição: investigue
- E sendo bem sincero, eu acho que o Whisper é mais lento no geral, bem mais lento do que o outro, e eu queria entender se a gente deveria tentar aqui uma abordagem diferente. Às vezes o Whisper vai funcionar melhor de outra forma. Por exemplo, não sei se é o caso, mas ele poderia meio que tentando escrever em tempo real, será que a gente consegue? Tipo, conforme tu vai falando, ele já vai escrevendo algo do tipo? Não sei, pode ser uma abordagem interessante, né?

- O que eu percebo é que a gente também deveria colocar na descrição dos modelos algo menos técnico, um pouco mais familiar para as pessoas. Então, quando ela vai escolher um modelo de transcrição, beleza, ter um nome entre parênteses, né? Mas deveria dizer assim, tipo, recomendado, que é o Parakeett, para a maioria dos casos, super rápido, recomendado. E o Whisper é meio que o maior controle, né? Que você pode selecionar entre submodelos small, large, não sei o que. Então, dá essa impressão na aplicação, sabe? De maneira mais clara. Eu acho que assim tá confuso. Fica difícil pra quem não é técnico escolher. E pra quem é técnico, também tá confuso. A gente tem que melhorar a usabilidade da aplicação.


- Nos modelos Whisper ativo, a gente faz a seleção entre modelo digitado e modelo de arquivo. Cara, eu acho que tem que tirar isso aí. Tem que botar assim, modelo ativo. É um só, pra tudo, entendeu? Vamos simplificar.

- Outra coisa é, não precisa no nome do modelo ativo tentar prever o tamanho dele ali. Eu acho que isso fica claro na hora que fizer o download ali. A gente até, o nome já dá a entender, né? Que é Tiny, Base, Small, Medium, sabe? Então, até porque a gente está prevendo valores errados. Por exemplo, está dizendo, a não ser que a gente botasse certo, né? Porque ali está dizendo mais ou menos 800 MB para o turbo. E quando eu baixo é 3.2 giga.

- A gente deveria permitir, de maneira muito fácil e intuitiva, você subir vários arquivos também, não apenas um, e ele gerar uma fila de transcrição ali, porque com o Parakeet é muito rápido, então daria para selecionar vários arquivos, botar em fila e mandar processar tudo.

- Na tela de seleção dos modelos de IA, quando eu clico para baixar, ele não está atualizando em tempo real. Na verdade, eu acho que a tela em si não está atualizando as coisas em tempo real. Eu estou tendo que trocar de tela e voltar para ver as atualizações de modelo baixando e tudo mais.


- O pós-processamento com o MLX simplesmente não funciona, está sendo ignorado (Aparece um ícone de alerta lá na banda, porém não abre nenhuma explicação. Não sei o que está acontecendo.).

- Tá acontecendo algo muito esquisito na hora de baixar os modelos aqui do MLX, que ele trava aqui e fecha a aplicação quando está concluindo o download. A gente precisa investigar.

- A gente tem duas interfaces diferentes de seleção de modelo, né? A gente deveria padronizar. Eu gostei dessa aqui do MLX local.

- Todo tipo de prompt que a gente usa por trás dos panos deveria ser editável pelo usuário. Não deveria ter nada escondido. A gente mostra ali e ele edita esse prompt. A gente pode limitar talvez a janela de prompt em modelos mais simples e permitir uma janela mais ampla em modelos mais complexos, mas não deveria tirar esse poder da mão do usuário. E ele sempre, claro, pode restaurar o padrão. Eu me refiro àqueles prompts somente leitura que tem quando a gente seleciona Apple Intelligence. Eu não vejo por que ser somente leitura não faz sentido pra mim. E E a gente deveria permitir sim, no modo personalizado, a pessoa construir, mas ela vai ter que estar claro ali que o provedor é mais fraquinho, né? O Apple Intelligence. Se ela selecionar, tem que ter um aviso, né? Não espere muito disso aqui, sabe? Algo nesse sentido. E aí a gente dá mais uma padronizada nas interfaces. Tudo que tem a ver com escrita de prompt só muda para modelo simples e modelo mais completo, mas ser tudo meio igual, sabe? Poder preencher, poder restaurar, tudo com a mesma carinha aí ao longo da aplicação, a gente componentizar isso e reaproveitar.

- Será que não faz sentido a gente simplificar e juntar um ou mais desses três itens, que seria licença, atualizações e sobre? Ocupa muito espaço no menu aqui e não parece que precisa, sabe? Poderia ser um item só de coisas relacionadas à aplicação nesse sentido, e aí o sub-itens lá dentro, ou algo do tipo, assim, não precisa tanto. O menu, quanto mais limpo ali, mais objetivo para o nosso usuário, eu acredito que é melhor, né?

- Talvez a gente deveria permitir ter mais de um modo personalizado ali. A pessoa poder ir adicionando e colocar alguns, sabe? Um só eu acho que tá pouco mesmo.

- Vamos fazer uma investigação, porque muitas vezes a aplicação é super rápida. Eu pego, falo no microfone, no que eu solto, ela já pega e escreve instantaneamente, em segundos, e às vezes dá uma travada nesse processo e fica lento ali, mesmo sendo no motor para-kit e fica muito lento. Vamos dar uma investigada nesse fluxo, ver se a gente está complicando em alguma coisa, que esse modo de transcrição rápida, cara, tem que ser a coisa mais otimizada da aplicação, assim, e funcionar sempre. É óbvio que existem exceções, mas o máximo que a gente conseguir proteger, deixar rápido e otimizado seria o ideal.

- Sobre os menus da aplicação ali de ajustes, algumas coisas eu acho que eu quero repensar em outros caminhos. Nós vamos redesenhar aqui como as coisas ficam. Por exemplo, no geral tem ali atalho de sistema, idioma do aplicativo, faz total sentido. Armazenamento, ele tem a ver só com a transcrição de arquivo. Então, talvez a gente deveria ter uma sessão com todas as opções que têm a ver com transcrição de arquivo.
A seção que a gente chama de modelos, você na verdade seleciona o motor de transcrição. E aí, dentro do motor, depois você seleciona o modelo. Então, ela deveria se chamar motor de transcrição, né?
Na sessão avançada, está falando de diarization, que é totalmente a ver com transcrição de arquivos, e substituição de texto no pós-processamento, que é totalmente a ver com transcrição de arquivos. Então, talvez são itens que poderiam ir para um para essa nova sessão de transcrição de arquivos.


---

- Quando eu abro a aplicação, ele está pedindo para acessar um arquivo de licença. Ele às vezes pede 3, 4 vezes. Parece que é a mesma solicitação. Não sei se ela varia, isso são arquivos diferentes, but I quero saber se tem como diminuir isso, fazer mais objetivo, sei lá. Talvez pedir uma autorização para acessar uma pasta. Não sei como que funciona. Mas é que digitar senha várias vezes é bem frustrante.


- Quando pede para reiniciar, porque eu mudei o motor, por exemplo, ou algo do tipo, ele só fecha, ele não reinicia. Precisa saber se tem como abrir de novo. E se não tiver, aí tem que instruir corretamente para fechar e depois que tem que abrir manual. Não pode dizer que vai reiniciar e, na verdade, tá só fechando, né?


- Na transcrição de arquivo, quando eu peço para cancelar, está demorando muito para cancelar. Tem como meio que interromper na hora?


-----

- Eu quero que a gente faça uma investigação do porquê que na transcrição de arquivo parece que está demorando. Eu não sei se o gargalo está no carregamento do arquivo, na conversão do arquivo, porque a transcrição em si ela é muito rápida. Na hora que ele diz que está transcrevendo, é absurdamente rápido, porém tem algum processo anterior ali que eu vejo que tem algum gargalo, alguma coisa travando, e eu queria investigar e saber o que a gente consegue otimizar. 
Eu cheguei a fazer um teste de converter o arquivo antes para WAV e colocar para rodar, mas mesmo assim demorou para carregar e começar a processar. Então eu tô achando isso estranho. Por que será que está ocorrendo, né?